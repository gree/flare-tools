use clap::{Arg, Command};
use std::collections::HashMap;
use std::process;
use std::io::{self, Write};

#[derive(Debug, Clone)]
struct Node {
    hostname: String,
    port: u16,
    role: String,
    state: String,
    partition: i32,
}

#[derive(Debug)]
struct ClusterNodes {
    masters: Vec<Node>,
    slaves: Vec<Node>,
}

fn main() {
    let matches = Command::new("flare-cluster-repl")
        .version("1.0.0")
        .about("Configure flare cluster replication between source and destination clusters")
        .arg(Arg::new("mode")
            .help("Replication mode: duplicate or forward")
            .required(true)
            .index(1)
            .value_parser(["duplicate", "forward"]))
        .arg(Arg::new("source")
            .help("Source index server (e.g., flarei-prod:12120)")
            .required(true)
            .index(2))
        .arg(Arg::new("destination")
            .help("Destination index server (e.g., flarei-staging:12130)")
            .required(true)
            .index(3))
        .arg(Arg::new("flared-port")
            .long("flared-port")
            .value_name("PORT")
            .help("Port for flared service")
            .default_value("13301"))
        .arg(Arg::new("environment")
            .long("env")
            .short('e')
            .value_name("ENV")
            .help("Environment type")
            .value_parser(["docker-compose", "aws", "local"])
            .default_value("docker-compose"))
        .arg(Arg::new("dry-run")
            .long("dry-run")
            .help("Show what would be done without making changes")
            .action(clap::ArgAction::SetTrue))
        .arg(Arg::new("verbose")
            .long("verbose")
            .short('v')
            .help("Show detailed progress")
            .action(clap::ArgAction::SetTrue))
        .arg(Arg::new("force")
            .long("force")
            .short('f')
            .help("Force update even if replication is already configured")
            .action(clap::ArgAction::SetTrue))
        .get_matches();

    let mode = matches.get_one::<String>("mode").unwrap();
    let source_server = matches.get_one::<String>("source").unwrap();
    let dest_server = matches.get_one::<String>("destination").unwrap();
    let flared_port = matches.get_one::<String>("flared-port").unwrap();
    let environment = matches.get_one::<String>("environment").unwrap();
    let dry_run = matches.get_flag("dry-run");
    let verbose = matches.get_flag("verbose");
    let force = matches.get_flag("force");

    if let Err(e) = run_replication_setup(
        mode,
        source_server,
        dest_server,
        flared_port,
        environment,
        dry_run,
        verbose,
        force,
    ) {
        eprintln!("Error: {}", e);
        process::exit(1);
    }
}

fn run_replication_setup(
    mode: &str,
    source_server: &str,
    dest_server: &str,
    flared_port: &str,
    environment: &str,
    dry_run: bool,
    verbose: bool,
    force: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("🔄 Setting up {} replication from {} to {}", mode, source_server, dest_server);
    
    // Parse source and destination servers
    let (source_host, source_port) = parse_server_address(source_server)?;
    let (dest_host, dest_port) = parse_server_address(dest_server)?;
    
    if verbose {
        println!("Source index server: {}:{}", source_host, source_port);
        println!("Destination index server: {}:{}", dest_host, dest_port);
        println!("Flared port: {}", flared_port);
        println!("Environment: {}", environment);
    }
    
    // Step 1: Query source cluster nodes
    println!("\n📊 Querying source cluster nodes...");
    let source_nodes = query_cluster_nodes(&source_host, source_port, verbose)?;
    
    if verbose {
        println!("Found {} masters and {} slaves in source cluster", 
            source_nodes.masters.len(), source_nodes.slaves.len());
    }
    
    // Step 2: Query destination cluster nodes
    println!("\n📊 Querying destination cluster nodes...");
    let dest_nodes = query_cluster_nodes(&dest_host, dest_port, verbose)?;
    
    if verbose {
        println!("Found {} masters and {} slaves in destination cluster", 
            dest_nodes.masters.len(), dest_nodes.slaves.len());
    }
    
    // Step 3: Create node mappings
    println!("\n🔗 Creating node mappings...");
    let mappings = create_node_mappings(mode, &source_nodes, &dest_nodes)?;
    
    if dry_run || verbose {
        println!("\nNode mappings:");
        for (source, dest) in &mappings {
            println!("  {}:{} ({}) → {}:{} ({})", 
                source.hostname, source.port, source.role,
                dest.hostname, dest.port, dest.role);
        }
    }
    
    // Step 4: Configure replication on each source node
    println!("\n⚙️  Configuring replication settings...");
    for (source_node, dest_node) in &mappings {
        configure_node_replication(
            source_node,
            dest_node,
            mode,
            flared_port,
            environment,
            dry_run,
            verbose,
            force,
        )?;
    }
    
    // Step 5: Reload configurations
    if !dry_run {
        println!("\n♻️  Reloading flare configurations...");
        reload_flare_configs(environment, &source_nodes, verbose)?;
    }
    
    println!("\n✅ Cluster replication setup completed successfully!");
    
    Ok(())
}

fn parse_server_address(server: &str) -> Result<(String, u16), Box<dyn std::error::Error>> {
    let parts: Vec<&str> = server.split(':').collect();
    if parts.len() != 2 {
        return Err(format!("Invalid server format: {}. Expected host:port", server).into());
    }
    
    let host = parts[0].to_string();
    let port = parts[1].parse::<u16>()
        .map_err(|_| format!("Invalid port number: {}", parts[1]))?;
    
    Ok((host, port))
}

fn query_cluster_nodes(host: &str, port: u16, verbose: bool) -> Result<ClusterNodes, Box<dyn std::error::Error>> {
    // Run flare-admin stats to get node information
    let output = process::Command::new("flare-admin")
        .args(&["--index-server", host])
        .args(&["--index-port", &port.to_string()])
        .arg("stats")
        .output()
        .map_err(|e| format!("Failed to run flare-admin: {}", e))?;
    
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("flare-admin stats failed: {}", stderr).into());
    }
    
    let stdout = String::from_utf8_lossy(&output.stdout);
    if verbose {
        println!("Raw stats output:\n{}", stdout);
    }
    
    // Parse the stats output
    let nodes = parse_stats_output(&stdout)?;
    
    // Separate masters and slaves
    let mut masters = Vec::new();
    let mut slaves = Vec::new();
    
    for node in nodes {
        match node.role.as_str() {
            "master" => masters.push(node),
            "slave" => slaves.push(node),
            _ => {} // Skip proxy and other roles
        }
    }
    
    Ok(ClusterNodes { masters, slaves })
}

fn parse_stats_output(output: &str) -> Result<Vec<Node>, Box<dyn std::error::Error>> {
    let mut nodes = Vec::new();
    let lines: Vec<&str> = output.lines().collect();
    
    // Skip header line
    for line in lines.iter().skip(1) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 5 {
            continue;
        }
        
        // Parse node:port
        let node_addr = parts[0];
        let addr_parts: Vec<&str> = node_addr.split(':').collect();
        if addr_parts.len() != 2 {
            continue;
        }
        
        let hostname = addr_parts[0].to_string();
        let port = addr_parts[1].parse::<u16>().unwrap_or(0);
        if port == 0 {
            continue;
        }
        
        let partition = parts[1].parse::<i32>().unwrap_or(-1);
        let role = parts[2].to_string();
        let state = parts[3].to_string();
        
        nodes.push(Node {
            hostname,
            port,
            role,
            state,
            partition,
        });
    }
    
    Ok(nodes)
}

fn create_node_mappings(
    mode: &str,
    source_nodes: &ClusterNodes,
    dest_nodes: &ClusterNodes,
) -> Result<Vec<(Node, Node)>, Box<dyn std::error::Error>> {
    let mut mappings = Vec::new();
    
    match mode {
        "duplicate" => {
            // For duplicate mode, only map masters to masters
            if dest_nodes.masters.is_empty() {
                return Err("No master nodes found in destination cluster".into());
            }
            
            for (i, source_master) in source_nodes.masters.iter().enumerate() {
                let dest_master = &dest_nodes.masters[i % dest_nodes.masters.len()];
                mappings.push((source_master.clone(), dest_master.clone()));
            }
        }
        "forward" => {
            // For forward mode, map all nodes
            // Map masters to masters
            if !source_nodes.masters.is_empty() && !dest_nodes.masters.is_empty() {
                for (i, source_master) in source_nodes.masters.iter().enumerate() {
                    let dest_master = &dest_nodes.masters[i % dest_nodes.masters.len()];
                    mappings.push((source_master.clone(), dest_master.clone()));
                }
            }
            
            // Map slaves to slaves
            if !source_nodes.slaves.is_empty() && !dest_nodes.slaves.is_empty() {
                for (i, source_slave) in source_nodes.slaves.iter().enumerate() {
                    let dest_slave = &dest_nodes.slaves[i % dest_nodes.slaves.len()];
                    mappings.push((source_slave.clone(), dest_slave.clone()));
                }
            }
        }
        _ => return Err(format!("Invalid mode: {}", mode).into()),
    }
    
    Ok(mappings)
}

fn configure_node_replication(
    source_node: &Node,
    dest_node: &Node,
    mode: &str,
    flared_port: &str,
    environment: &str,
    dry_run: bool,
    verbose: bool,
    force: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let node_id = format!("{}:{}", source_node.hostname, source_node.port);
    
    if verbose {
        println!("\nConfiguring replication for {}", node_id);
    }
    
    // Build the configuration lines
    let config_lines = vec![
        format!("cluster-replication = true"),
        format!("cluster-replication-server-name = {}", dest_node.hostname),
        format!("cluster-replication-server-port = {}", dest_node.port),
        format!("cluster-replication-concurrency = 8"),
        format!("cluster-replication-mode = {}", mode),
    ];
    
    if dry_run {
        println!("DRY RUN: Would update /etc/flared.conf on {}:", node_id);
        for line in &config_lines {
            println!("  {}", line);
        }
        return Ok(());
    }
    
    match environment {
        "docker-compose" => {
            configure_docker_node(source_node, &config_lines, force, verbose)?;
        }
        "aws" => {
            configure_aws_node(source_node, &config_lines, force, verbose)?;
        }
        "local" => {
            configure_local_node(source_node, &config_lines, force, verbose)?;
        }
        _ => return Err(format!("Unsupported environment: {}", environment).into()),
    }
    
    Ok(())
}

fn configure_docker_node(
    node: &Node,
    config_lines: &[String],
    force: bool,
    verbose: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    // Map node to container name (simplified - you might need more sophisticated mapping)
    let container_name = get_docker_container_name(node)?;
    
    // Check if replication is already configured
    if !force {
        let check_cmd = format!("docker exec {} grep -q 'cluster-replication' /etc/flared.conf", container_name);
        let check = process::Command::new("sh")
            .arg("-c")
            .arg(&check_cmd)
            .output()?;
        
        if check.status.success() {
            println!("⚠️  Replication already configured on {}. Use --force to override.", container_name);
            return Ok(());
        }
    }
    
    // Update the configuration
    for line in config_lines {
        let key = line.split(" = ").next().unwrap_or("");
        let value = line.split(" = ").nth(1).unwrap_or("");
        
        // First, try to update existing line
        let update_cmd = format!(
            "docker exec {} sh -c \"sed -i 's/^{}.*/{}/g' /etc/flared.conf\"",
            container_name, key, line.replace("/", "\\/")
        );
        
        if verbose {
            println!("Running: {}", update_cmd);
        }
        
        let update = process::Command::new("sh")
            .arg("-c")
            .arg(&update_cmd)
            .output()?;
        
        // If key doesn't exist, append it
        let check_cmd = format!("docker exec {} grep -q '^{}' /etc/flared.conf", container_name, key);
        let exists = process::Command::new("sh")
            .arg("-c")
            .arg(&check_cmd)
            .output()?;
        
        if !exists.status.success() {
            let append_cmd = format!(
                "docker exec {} sh -c \"echo '{}' >> /etc/flared.conf\"",
                container_name, line
            );
            
            if verbose {
                println!("Appending: {}", append_cmd);
            }
            
            process::Command::new("sh")
                .arg("-c")
                .arg(&append_cmd)
                .output()?;
        }
    }
    
    println!("✓ Configured replication on {}", container_name);
    Ok(())
}

fn configure_aws_node(
    node: &Node,
    config_lines: &[String],
    force: bool,
    verbose: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    // AWS implementation would use SSM commands
    // This is a placeholder
    Err("AWS support not yet implemented".into())
}

fn configure_local_node(
    node: &Node,
    config_lines: &[String],
    force: bool,
    verbose: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    // Local implementation would use SSH or direct file access
    // This is a placeholder
    Err("Local support not yet implemented".into())
}

fn get_docker_container_name(node: &Node) -> Result<String, Box<dyn std::error::Error>> {
    // Query docker to get container names and match by hostname
    let output = process::Command::new("docker")
        .args(&["ps", "--format", "{{.Names}}"])
        .output()
        .map_err(|e| format!("Failed to query docker containers: {}", e))?;
    
    if !output.status.success() {
        return Err("Failed to list docker containers".into());
    }
    
    let containers = String::from_utf8_lossy(&output.stdout);
    
    // Try to find exact match first (hostname without port)
    for container in containers.lines() {
        if container == node.hostname {
            return Ok(container.to_string());
        }
    }
    
    // Try to find containers that contain the node hostname
    for container in containers.lines() {
        if container.contains(&node.hostname) {
            return Ok(container.to_string());
        }
    }
    
    Err(format!("Could not find container for node {}. Available containers:\n{}", 
        node.hostname, containers.trim()).into())
}

fn reload_flare_configs(
    environment: &str,
    nodes: &ClusterNodes,
    verbose: bool,
) -> Result<(), Box<dyn std::error::Error>> {
    let all_nodes: Vec<&Node> = nodes.masters.iter().chain(nodes.slaves.iter()).collect();
    
    match environment {
        "docker-compose" => {
            for node in all_nodes {
                let container_name = get_docker_container_name(node)?;
                let reload_cmd = format!("docker exec {} pkill -HUP flared", container_name);
                
                if verbose {
                    println!("Reloading config on {}", container_name);
                }
                
                let output = process::Command::new("sh")
                    .arg("-c")
                    .arg(&reload_cmd)
                    .output()?;
                
                if !output.status.success() {
                    println!("⚠️  Warning: Failed to reload config on {}", container_name);
                }
            }
        }
        "aws" => {
            return Err("AWS reload not yet implemented".into());
        }
        "local" => {
            return Err("Local reload not yet implemented".into());
        }
        _ => {}
    }
    
    println!("✓ Configuration reloaded on all nodes");
    Ok(())
}