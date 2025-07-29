use clap::{Arg, Command, ValueEnum};
use serde::{Deserialize, Serialize};
use std::process;
use std::fs;

#[cfg(feature = "aws")]
use aws_config::BehaviorVersion;
#[cfg(feature = "aws")]
use aws_sdk_ssm::{Client as SsmClient, types::CommandStatus};
#[cfg(feature = "aws")]
use aws_sdk_ec2::{Client as Ec2Client, types::Filter};
#[cfg(feature = "aws")]
use std::time::Duration;
#[cfg(feature = "aws")]
use tokio::time::sleep;

#[derive(Debug, Clone, ValueEnum)]
enum Environment {
    #[value(name = "docker-compose")]
    DockerCompose,
    #[value(name = "aws")]
    Aws,
}

#[derive(Debug, Serialize, Deserialize)]
struct ClusterConfig {
    name: String,
    nodes: Vec<NodeConfig>,
}

#[derive(Debug, Serialize, Deserialize)]
struct NodeConfig {
    name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    instance_id: Option<String>, // For AWS
    #[serde(skip_serializing_if = "Option::is_none")]
    container_name: Option<String>, // For Docker Compose
    role: String,
    balance: i32,
    partition: i32,
}

#[derive(Debug)]
struct ReplicationCommand {
    environment: Environment,
    cluster_name: String,
    dry_run: bool,
    verbose: bool,
    #[cfg(feature = "aws")]
    ssm_client: Option<SsmClient>,
    #[cfg(feature = "aws")]
    ec2_client: Option<Ec2Client>,
}

impl ReplicationCommand {
    #[cfg(feature = "aws")]
    async fn new_aws(cluster_name: String, dry_run: bool, verbose: bool) -> Result<Self, Box<dyn std::error::Error>> {
        let config = aws_config::defaults(BehaviorVersion::latest()).load().await;
        let ssm_client = SsmClient::new(&config);
        let ec2_client = Ec2Client::new(&config);

        Ok(ReplicationCommand {
            environment: Environment::Aws,
            cluster_name,
            dry_run,
            verbose,
            ssm_client: Some(ssm_client),
            ec2_client: Some(ec2_client),
        })
    }

    fn new_docker_compose(cluster_name: String, dry_run: bool, verbose: bool) -> Self {
        ReplicationCommand {
            environment: Environment::DockerCompose,
            cluster_name,
            dry_run,
            verbose,
            #[cfg(feature = "aws")]
            ssm_client: None,
            #[cfg(feature = "aws")]
            ec2_client: None,
        }
    }

    async fn new(environment: Environment, cluster_name: String, dry_run: bool, verbose: bool) -> Result<Self, Box<dyn std::error::Error>> {
        match environment {
            Environment::DockerCompose => Ok(Self::new_docker_compose(cluster_name, dry_run, verbose)),
            #[cfg(feature = "aws")]
            Environment::Aws => Self::new_aws(cluster_name, dry_run, verbose).await,
            #[cfg(not(feature = "aws"))]
            Environment::Aws => Err("AWS support not enabled. Rebuild with --features aws".into()),
        }
    }

    async fn setup_cluster_replication(&self, config_file: &str) -> Result<(), Box<dyn std::error::Error>> {
        // Read cluster configuration
        let config_content = fs::read_to_string(config_file)
            .map_err(|e| format!("Failed to read config file {}: {}", config_file, e))?;
        
        let config: ClusterConfig = serde_json::from_str(&config_content)
            .map_err(|e| format!("Failed to parse config file: {}", e))?;

        if self.verbose {
            println!("Setting up replication for cluster: {}", config.name);
            println!("Found {} nodes in configuration", config.nodes.len());
            println!("Environment: {:?}", self.environment);
        }

        match self.environment {
            Environment::DockerCompose => self.setup_docker_compose_replication(&config).await,
            Environment::Aws => self.setup_aws_replication(&config).await,
        }
    }

    async fn setup_docker_compose_replication(&self, config: &ClusterConfig) -> Result<(), Box<dyn std::error::Error>> {
        for node in &config.nodes {
            let container_name = node.container_name.as_ref()
                .ok_or_else(|| format!("container_name is required for node {} in docker-compose environment", node.name))?;

            if self.verbose {
                println!("Configuring container: {}", container_name);
            }

            if self.dry_run {
                println!("DRY RUN: Would update replication settings in /etc/flared.conf for container {}:", container_name);
                println!("  replication-enabled true");
                println!("  replication-role {}", node.role);
                println!("  server-name {}", node.name);
                println!("  server-balance {}", node.balance);
                println!("  server-partition {}", node.partition);
                println!("  Would reload config using SIGHUP");
            } else {
                // Read existing config from container
                let read_config_cmd = format!("docker exec {} cat /etc/flared.conf", container_name);
                let config_output = std::process::Command::new("sh")
                    .arg("-c")
                    .arg(&read_config_cmd)
                    .output()
                    .map_err(|e| format!("Failed to read existing config: {}", e))?;

                if !config_output.status.success() {
                    let stderr = String::from_utf8_lossy(&config_output.stderr);
                    return Err(format!("Failed to read config from {}: {}", container_name, stderr).into());
                }

                let existing_config = String::from_utf8_lossy(&config_output.stdout);
                let updated_config = self.update_flared_conf(&existing_config, node)?;

                // Write updated config back to container
                let temp_file = format!("/tmp/flared_{}.conf", node.name);
                fs::write(&temp_file, &updated_config)
                    .map_err(|e| format!("Failed to write temp config file: {}", e))?;

                let docker_cp_cmd = format!("docker cp {} {}:/etc/flared.conf", temp_file, container_name);
                if self.verbose {
                    println!("Updating config in container: {}", container_name);
                }

                let output = std::process::Command::new("sh")
                    .arg("-c")
                    .arg(&docker_cp_cmd)
                    .output()
                    .map_err(|e| format!("Failed to execute docker cp: {}", e))?;

                if !output.status.success() {
                    let stderr = String::from_utf8_lossy(&output.stderr);
                    return Err(format!("Docker cp failed for {}: {}", container_name, stderr).into());
                }

                // Clean up temp file
                let _ = fs::remove_file(&temp_file);

                // Reload flared configuration using SIGHUP
                let reload_cmd = format!("docker exec {} sh -c 'pkill -HUP flared'", container_name);
                if self.verbose {
                    println!("Reloading flared configuration in container: {}", container_name);
                }

                let reload_output = std::process::Command::new("sh")
                    .arg("-c")
                    .arg(&reload_cmd)
                    .output()
                    .map_err(|e| format!("Failed to reload flared: {}", e))?;

                if !reload_output.status.success() {
                    let stderr = String::from_utf8_lossy(&reload_output.stderr);
                    println!("Warning: Failed to reload flared configuration in {}: {}", container_name, stderr);
                }
            }
        }

        println!("✓ Docker compose cluster replication setup completed");
        Ok(())
    }

    #[cfg(feature = "aws")]
    async fn setup_aws_replication(&self, config: &ClusterConfig) -> Result<(), Box<dyn std::error::Error>> {
        // Get instance IDs for the cluster
        let instance_ids = self.get_cluster_instances().await?;

        // Build replication configuration commands
        let mut commands = Vec::new();

        // Stop flare services
        commands.push("sudo systemctl stop flared flarei".to_string());

        // Update flare configuration with replication settings
        for node in &config.nodes {
            // Read existing config, update it, then write back
            let read_cmd = "cat /etc/flared.conf".to_string();
            commands.push(read_cmd);
            
            // Create a script to update the config
            let update_script = format!(
                r#"
                config=$(cat /etc/flared.conf)
                echo "$config" | sed -E 's/^replication-enabled.*/replication-enabled true/' | \
                sed -E 's/^replication-role.*/replication-role {}/' | \
                sed -E 's/^server-name.*/server-name {}/' | \
                sed -E 's/^server-balance.*/server-balance {}/' | \
                sed -E 's/^server-partition.*/server-partition {}/' > /tmp/flared_new.conf
                
                # Add missing settings if they don't exist
                grep -q '^replication-enabled' /tmp/flared_new.conf || echo 'replication-enabled true' >> /tmp/flared_new.conf
                grep -q '^replication-role' /tmp/flared_new.conf || echo 'replication-role {}' >> /tmp/flared_new.conf
                grep -q '^server-name' /tmp/flared_new.conf || echo 'server-name {}' >> /tmp/flared_new.conf
                grep -q '^server-balance' /tmp/flared_new.conf || echo 'server-balance {}' >> /tmp/flared_new.conf
                grep -q '^server-partition' /tmp/flared_new.conf || echo 'server-partition {}' >> /tmp/flared_new.conf
                
                sudo cp /tmp/flared_new.conf /etc/flared.conf
                "#,
                node.role, node.name, node.balance, node.partition,
                node.role, node.name, node.balance, node.partition
            );
            
            commands.push(update_script);
        }

        // Reload flare configuration using SIGHUP (graceful reload)
        commands.push("sudo pkill -HUP flared".to_string());
        commands.push("sudo pkill -HUP flarei".to_string());
        
        // Ensure services are enabled and running
        commands.push("sudo systemctl enable flared flarei".to_string());
        commands.push("sudo systemctl start flared flarei".to_string());

        // Execute all commands
        for (i, command) in commands.iter().enumerate() {
            if self.verbose {
                println!("Step {}/{}: {}", i + 1, commands.len(), command);
            }
            self.execute_command_on_instances(&instance_ids, command).await?;
            
            // Small delay between commands
            if !self.dry_run {
                sleep(Duration::from_secs(2)).await;
            }
        }

        println!("✓ AWS cluster replication setup completed successfully");
        Ok(())
    }

    #[cfg(not(feature = "aws"))]
    async fn setup_aws_replication(&self, _config: &ClusterConfig) -> Result<(), Box<dyn std::error::Error>> {
        Err("AWS support not enabled. Rebuild with --features aws".into())
    }

    fn update_flared_conf(&self, existing_config: &str, node: &NodeConfig) -> Result<String, Box<dyn std::error::Error>> {
        let mut lines: Vec<String> = existing_config.lines().map(|s| s.to_string()).collect();
        
        // Settings to update/add
        let settings = [
            ("replication-enabled", "true"),
            ("replication-role", &node.role),
            ("server-name", &node.name),
            ("server-balance", &node.balance.to_string()),
            ("server-partition", &node.partition.to_string()),
        ];

        for (key, value) in &settings {
            let mut found = false;
            
            // Update existing setting
            for line in &mut lines {
                let trimmed = line.trim();
                if trimmed.starts_with(key) && (trimmed.contains(' ') || trimmed.contains('\t')) {
                    *line = format!("{} {}", key, value);
                    found = true;
                    break;
                }
            }
            
            // Add new setting if not found
            if !found {
                lines.push(format!("{} {}", key, value));
            }
        }

        Ok(lines.join("\n"))
    }

    #[cfg(feature = "aws")]
    async fn get_cluster_instances(&self) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        let ec2_client = self.ec2_client.as_ref().ok_or("EC2 client not initialized")?;

        if self.verbose {
            println!("Finding instances for cluster: {}", self.cluster_name);
        }

        let filter = Filter::builder()
            .name("tag:flare-cluster")
            .values(&self.cluster_name)
            .build();

        let running_filter = Filter::builder()
            .name("instance-state-name")
            .values("running")
            .build();

        let resp = ec2_client
            .describe_instances()
            .filters(filter)
            .filters(running_filter)
            .send()
            .await?;

        let mut instance_ids = Vec::new();
        for reservation in resp.reservations() {
            for instance in reservation.instances() {
                if let Some(instance_id) = instance.instance_id() {
                    instance_ids.push(instance_id.to_string());
                    if self.verbose {
                        println!("Found instance: {}", instance_id);
                    }
                }
            }
        }

        if instance_ids.is_empty() {
            return Err(format!("No running instances found for cluster: {}", self.cluster_name).into());
        }

        Ok(instance_ids)
    }

    #[cfg(feature = "aws")]
    async fn execute_command_on_instances(
        &self,
        instance_ids: &[String],
        command: &str,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let ssm_client = self.ssm_client.as_ref().ok_or("SSM client not initialized")?;

        if self.dry_run {
            println!("DRY RUN: Would execute command on {} instances:", instance_ids.len());
            println!("Command: {}", command);
            for instance_id in instance_ids {
                println!("  Instance: {}", instance_id);
            }
            return Ok(());
        }

        if self.verbose {
            println!("Executing command on {} instances: {}", instance_ids.len(), command);
        }

        let resp = ssm_client
            .send_command()
            .instance_ids(instance_ids[0].clone())
            .set_instance_ids(Some(instance_ids.to_vec()))
            .document_name("AWS-RunShellScript")
            .parameters("commands", vec![command.to_string()])
            .send()
            .await?;

        let command_id = resp.command()
            .and_then(|c| c.command_id())
            .ok_or("Failed to get command ID")?;

        if self.verbose {
            println!("Command ID: {}", command_id);
            println!("Waiting for command completion...");
        }

        // Wait for command completion
        self.wait_for_command_completion(command_id, instance_ids).await?;
        Ok(())
    }

    #[cfg(feature = "aws")]
    async fn wait_for_command_completion(
        &self,
        command_id: &str,
        instance_ids: &[String],
    ) -> Result<(), Box<dyn std::error::Error>> {
        let ssm_client = self.ssm_client.as_ref().ok_or("SSM client not initialized")?;
        let mut attempts = 0;
        let max_attempts = 60; // 5 minutes with 5-second intervals

        loop {
            attempts += 1;
            
            let mut all_completed = true;
            let mut any_failed = false;

            for instance_id in instance_ids {
                let resp = ssm_client
                    .get_command_invocation()
                    .command_id(command_id)
                    .instance_id(instance_id)
                    .send()
                    .await?;

                match resp.status() {
                    Some(CommandStatus::Success) => {
                        if self.verbose {
                            println!("✓ Command completed successfully on {}", instance_id);
                        }
                    }
                    Some(CommandStatus::Failed) => {
                        println!("✗ Command failed on {}", instance_id);
                        if let Some(output) = resp.standard_error_content() {
                            println!("Error output: {}", output);
                        }
                        any_failed = true;
                        all_completed = true; // Consider failed as completed
                    }
                    Some(CommandStatus::InProgress) => {
                        all_completed = false;
                        if self.verbose {
                            println!("⏳ Command still running on {}", instance_id);
                        }
                    }
                    _ => {
                        all_completed = false;
                    }
                }
            }

            if all_completed {
                if any_failed {
                    return Err("One or more commands failed".into());
                }
                break;
            }

            if attempts >= max_attempts {
                return Err("Command execution timed out".into());
            }

            sleep(Duration::from_secs(5)).await;
        }

        Ok(())
    }

    async fn stop_cluster(&self) -> Result<(), Box<dyn std::error::Error>> {
        match self.environment {
            Environment::DockerCompose => {
                println!("Stopping docker-compose cluster services");
                if self.dry_run {
                    println!("DRY RUN: Would execute: docker-compose stop");
                } else {
                    let output = std::process::Command::new("docker-compose")
                        .arg("stop")
                        .output()
                        .map_err(|e| format!("Failed to stop docker-compose: {}", e))?;

                    if !output.status.success() {
                        let stderr = String::from_utf8_lossy(&output.stderr);
                        return Err(format!("Docker-compose stop failed: {}", stderr).into());
                    }
                }
                println!("✓ Docker-compose cluster services stopped");
            }
            #[cfg(feature = "aws")]
            Environment::Aws => {
                let instance_ids = self.get_cluster_instances().await?;
                let command = "sudo systemctl stop flared flarei";
                
                println!("Stopping flare services on {} instances", instance_ids.len());
                self.execute_command_on_instances(&instance_ids, command).await?;
                println!("✓ AWS cluster services stopped");
            }
            #[cfg(not(feature = "aws"))]
            Environment::Aws => {
                return Err("AWS support not enabled. Rebuild with --features aws".into());
            }
        }
        
        Ok(())
    }

    async fn start_cluster(&self) -> Result<(), Box<dyn std::error::Error>> {
        match self.environment {
            Environment::DockerCompose => {
                println!("Starting docker-compose cluster services");
                if self.dry_run {
                    println!("DRY RUN: Would execute: docker-compose up -d");
                } else {
                    let output = std::process::Command::new("docker-compose")
                        .args(&["up", "-d"])
                        .output()
                        .map_err(|e| format!("Failed to start docker-compose: {}", e))?;

                    if !output.status.success() {
                        let stderr = String::from_utf8_lossy(&output.stderr);
                        return Err(format!("Docker-compose up failed: {}", stderr).into());
                    }
                }
                println!("✓ Docker-compose cluster services started");
            }
            #[cfg(feature = "aws")]
            Environment::Aws => {
                let instance_ids = self.get_cluster_instances().await?;
                let command = "sudo systemctl start flared flarei";
                
                println!("Starting flare services on {} instances", instance_ids.len());
                self.execute_command_on_instances(&instance_ids, command).await?;
                println!("✓ AWS cluster services started");
            }
            #[cfg(not(feature = "aws"))]
            Environment::Aws => {
                return Err("AWS support not enabled. Rebuild with --features aws".into());
            }
        }
        
        Ok(())
    }

    async fn status_cluster(&self) -> Result<(), Box<dyn std::error::Error>> {
        match self.environment {
            Environment::DockerCompose => {
                println!("Checking docker-compose cluster status");
                if self.dry_run {
                    println!("DRY RUN: Would execute: docker-compose ps");
                } else {
                    let output = std::process::Command::new("docker-compose")
                        .arg("ps")
                        .output()
                        .map_err(|e| format!("Failed to check docker-compose status: {}", e))?;

                    println!("{}", String::from_utf8_lossy(&output.stdout));
                    if !output.stderr.is_empty() {
                        println!("Errors: {}", String::from_utf8_lossy(&output.stderr));
                    }
                }
            }
            #[cfg(feature = "aws")]
            Environment::Aws => {
                let instance_ids = self.get_cluster_instances().await?;
                let command = "sudo systemctl status flared flarei --no-pager -l";
                
                println!("Checking status of flare services on {} instances", instance_ids.len());
                self.execute_command_on_instances(&instance_ids, command).await?;
            }
            #[cfg(not(feature = "aws"))]
            Environment::Aws => {
                return Err("AWS support not enabled. Rebuild with --features aws".into());
            }
        }
        
        Ok(())
    }

    async fn reload_cluster(&self) -> Result<(), Box<dyn std::error::Error>> {
        match self.environment {
            Environment::DockerCompose => {
                println!("Reloading docker-compose cluster configurations");
                if self.dry_run {
                    println!("DRY RUN: Would execute: docker-compose exec flared1 pkill -HUP flared");
                    println!("DRY RUN: Would execute: docker-compose exec flared2 pkill -HUP flared");
                    println!("DRY RUN: Would execute: docker-compose exec flared3 pkill -HUP flared");
                    println!("DRY RUN: Would execute: docker-compose exec flared4 pkill -HUP flared");
                } else {
                    // Get list of running flared containers
                    let containers = ["flared1", "flared2", "flared3", "flared4"];
                    
                    for container in &containers {
                        let reload_cmd = format!("docker exec {} sh -c 'pkill -HUP flared'", container);
                        if self.verbose {
                            println!("Reloading configuration in container: {}", container);
                        }
                        
                        let output = std::process::Command::new("sh")
                            .arg("-c")
                            .arg(&reload_cmd)
                            .output()
                            .map_err(|e| format!("Failed to reload {}: {}", container, e))?;

                        if !output.status.success() {
                            let stderr = String::from_utf8_lossy(&output.stderr);
                            println!("Warning: Failed to reload {}: {}", container, stderr);
                        } else if self.verbose {
                            println!("✓ Successfully reloaded {}", container);
                        }
                    }
                }
                println!("✓ Docker-compose cluster configurations reloaded");
            }
            #[cfg(feature = "aws")]
            Environment::Aws => {
                let instance_ids = self.get_cluster_instances().await?;
                let command = "sudo pkill -HUP flared; sudo pkill -HUP flarei";
                
                println!("Reloading flare configurations on {} instances", instance_ids.len());
                self.execute_command_on_instances(&instance_ids, command).await?;
                println!("✓ AWS cluster configurations reloaded");
            }
            #[cfg(not(feature = "aws"))]
            Environment::Aws => {
                return Err("AWS support not enabled. Rebuild with --features aws".into());
            }
        }
        
        Ok(())
    }
}

#[tokio::main]
async fn main() {
    let matches = Command::new("flare-cluster-repl")
        .version("1.0.0")
        .about("Flare cluster replication configuration tool")
        .arg(
            Arg::new("cluster")
                .short('c')
                .long("cluster")
                .value_name("NAME")
                .help("Cluster name")
                .required(true),
        )
        .arg(
            Arg::new("environment")
                .short('e')
                .long("environment")
                .value_name("ENV")
                .help("Target environment")
                .value_parser(clap::value_parser!(Environment))
                .default_value("docker-compose"),
        )
        .arg(
            Arg::new("dry-run")
                .long("dry-run")
                .help("Show what would be done without executing")
                .action(clap::ArgAction::SetTrue),
        )
        .arg(
            Arg::new("verbose")
                .short('v')
                .long("verbose")
                .help("Verbose output")
                .action(clap::ArgAction::SetTrue),
        )
        .subcommand(
            Command::new("setup")
                .about("Setup cluster replication")
                .arg(
                    Arg::new("config")
                        .short('f')
                        .long("config")
                        .value_name("FILE")
                        .help("Configuration file path")
                        .required(true),
                ),
        )
        .subcommand(Command::new("stop").about("Stop cluster services"))
        .subcommand(Command::new("start").about("Start cluster services"))
        .subcommand(Command::new("status").about("Check cluster status"))
        .subcommand(Command::new("reload").about("Reload cluster configurations using SIGHUP"))
        .get_matches();

    let cluster_name = matches.get_one::<String>("cluster").unwrap().clone();
    let environment = matches.get_one::<Environment>("environment").unwrap().clone();
    let dry_run = matches.get_flag("dry-run");
    let verbose = matches.get_flag("verbose");

    let repl_cmd = match ReplicationCommand::new(environment, cluster_name, dry_run, verbose).await {
        Ok(cmd) => cmd,
        Err(e) => {
            eprintln!("Failed to initialize replication command: {}", e);
            process::exit(1);
        }
    };

    let result = match matches.subcommand() {
        Some(("setup", sub_matches)) => {
            let config_file = sub_matches.get_one::<String>("config").unwrap();
            repl_cmd.setup_cluster_replication(config_file).await
        }
        Some(("stop", _)) => repl_cmd.stop_cluster().await,
        Some(("start", _)) => repl_cmd.start_cluster().await,
        Some(("status", _)) => repl_cmd.status_cluster().await,
        Some(("reload", _)) => repl_cmd.reload_cluster().await,
        _ => {
            eprintln!("Please specify a subcommand. Use --help for more information.");
            process::exit(1);
        }
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_update_flared_conf() {
        let existing_config = r#"# Flare configuration file
data-dir /var/lib/flare
log-facility local0
thread-type single
thread-pool-size 1
pid-file /tmp/flared.pid
server-name old-server
server-balance 50
server-partition 0
# replication settings will be added/updated below"#;

        let node = NodeConfig {
            name: "new-server".to_string(),
            container_name: Some("container1".to_string()),
            instance_id: None,
            role: "master".to_string(),
            balance: 100,
            partition: 1,
        };

        let repl_cmd = ReplicationCommand::new_docker_compose("test".to_string(), false, false);
        let updated_config = repl_cmd.update_flared_conf(existing_config, &node).unwrap();

        println!("Original config:");
        println!("{}", existing_config);
        println!("\nUpdated config:");
        println!("{}", updated_config);

        // Verify the updates
        assert!(updated_config.contains("replication-enabled true"));
        assert!(updated_config.contains("replication-role master"));
        assert!(updated_config.contains("server-name new-server"));
        assert!(updated_config.contains("server-balance 100"));
        assert!(updated_config.contains("server-partition 1"));
        
        // Verify existing settings are preserved
        assert!(updated_config.contains("data-dir /var/lib/flare"));
        assert!(updated_config.contains("log-facility local0"));
        assert!(updated_config.contains("thread-type single"));
    }
}