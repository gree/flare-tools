use std::process::Command;
use std::thread;
use std::time::Duration;
use std::fs;

/// Helper function to launch multi-cluster docker compose
fn launch_multi_cluster() -> Result<(), std::io::Error> {
    println!("🚀 Launching multi-cluster Docker Compose setup...");
    
    let output = Command::new("docker")
        .args(&["compose", "-f", "docker-compose-multi-cluster.yml", "up", "-d"])
        .stdin(std::process::Stdio::null())
        .output()?;
    
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        eprintln!("Failed to launch multi-cluster: {}", stderr);
        return Err(std::io::Error::new(std::io::ErrorKind::Other, "Docker compose up failed"));
    }
    
    println!("✓ Multi-cluster setup launched");
    
    // Wait for containers to be ready
    println!("⏳ Waiting for containers to be ready...");
    thread::sleep(Duration::from_secs(10));
    
    Ok(())
}

/// Helper function to shut down multi-cluster docker compose
fn shutdown_multi_cluster() -> Result<(), std::io::Error> {
    println!("🛑 Shutting down multi-cluster Docker Compose setup...");
    
    let output = Command::new("docker")
        .args(&["compose", "-f", "docker-compose-multi-cluster.yml", "down"])
        .stdin(std::process::Stdio::null())
        .output()?;
    
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        eprintln!("Failed to shutdown multi-cluster: {}", stderr);
        return Err(std::io::Error::new(std::io::ErrorKind::Other, "Docker compose down failed"));
    }
    
    println!("✓ Multi-cluster setup shut down");
    Ok(())
}

/// Helper function to setup cluster topology without managing Docker lifecycle
fn setup_cluster_topology() {
    println!("Setting up cluster topology...");
    
    // Setup production cluster topology
    println!("Setting up production cluster topology...");
    
    // Create master nodes
    let (success, stdout, stderr) = run_flare_admin(&[
        "--force",
        "-i", "flarei-prod:12120",
        "master",
        "flare-prod-master-1:12121:200:0",
        "flare-prod-master-2:12121:200:1"
    ]);
    
    if !success {
        println!("Master setup failed - stdout: {}, stderr: {}", stdout, stderr);
    }
    assert!(success, "Should be able to create master nodes");
    println!("✓ Production master nodes created");
    
    // Create slave nodes  
    let (success, stdout, stderr) = run_flare_admin(&[
        "--force",
        "-i", "flarei-prod:12120",
        "slave",
        "flare-prod-slave-1:12121:200:0",
        "flare-prod-slave-2:12121:200:1"
    ]);
    
    if !success {
        println!("Slave setup failed - stdout: {}, stderr: {}", stdout, stderr);
    }
    assert!(success, "Should be able to create slave nodes");
    println!("✓ Production slave nodes created");
    
    // Setup staging cluster topology
    println!("Setting up staging cluster topology...");
    
    // Create master node
    let (success, stdout, stderr) = run_flare_admin(&[
        "--force",
        "-i", "flarei-staging:12130",
        "master",
        "flare-staging-master-1:12121:150:0"
    ]);
    
    if !success {
        println!("Staging master setup failed - stdout: {}, stderr: {}", stdout, stderr); 
    }
    assert!(success, "Should be able to create staging master node");
    println!("✓ Staging master node created");
    
    // Create slave node
    let (success, stdout, stderr) = run_flare_admin(&[
        "--force",
        "-i", "flarei-staging:12130",
        "slave",
        "flare-staging-slave-1:12121:150:0" 
    ]);
    
    if !success {
        println!("Staging slave setup failed - stdout: {}, stderr: {}", stdout, stderr);
    }
    assert!(success, "Should be able to create staging slave node");
    println!("✓ Staging slave node created");
    
    println!("✓ Cluster topology setup completed");
}

/// Helper function to run flare-admin command and return output
fn run_flare_admin(args: &[&str]) -> (bool, String, String) {
    println!("🔧 Running command: flare-admin {}", args.join(" "));
    
    let output = Command::new("./target/debug/flare-admin")
        .args(args)
        .stdin(std::process::Stdio::null())
        .output()
        .expect("Failed to execute flare-admin");
    
    let success = output.status.success();
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();
    
    if success {
        println!("✓ Command completed successfully");
    } else {
        println!("❌ Command failed: {}", stderr);
    }
    
    (success, stdout, stderr)
}

/// Helper function to run flare-cluster-repl command and return output
fn run_flare_cluster_repl(args: &[&str]) -> (bool, String, String) {
    run_flare_cluster_repl_with_timeout(args, 10) // 10 second timeout
}

/// Helper function to run flare-cluster-repl command with timeout and verbose logging
fn run_flare_cluster_repl_with_timeout(args: &[&str], timeout_secs: u64) -> (bool, String, String) {
    println!("🔧 Running command: flare-cluster-repl {}", args.join(" "));
    
    let start = std::time::Instant::now();
    let mut child = Command::new("./target/debug/flare-cluster-repl")
        .args(args)
        .stdin(std::process::Stdio::null()) // Prevent hanging on stdin
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .expect("Failed to execute flare-cluster-repl");
    
    // Wait for the command with timeout
    let mut elapsed = 0;
    let check_interval = Duration::from_millis(100);
    
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                println!("✓ Command completed in {:.2}s", start.elapsed().as_secs_f64());
                let output = child.wait_with_output().unwrap();
                let success = status.success();
                let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                let stderr = String::from_utf8_lossy(&output.stderr).to_string();
                return (success, stdout, stderr);
            }
            Ok(None) => {
                // Still running
                elapsed += 1;
                if elapsed * 100 >= timeout_secs * 1000 {
                    println!("⚠ Command timeout after {}s, killing process", timeout_secs);
                    let _ = child.kill();
                    let _ = child.wait();
                    return (false, String::new(), format!("Command timed out after {}s", timeout_secs));
                }
                thread::sleep(check_interval);
            }
            Err(e) => {
                println!("❌ Error waiting for command: {}", e);
                return (false, String::new(), format!("Process error: {}", e));
            }
        }
    }
}

/// Helper function to create test configuration files
fn setup_test_configs() {
    // Production cluster config
    let prod_config = r#"{
  "name": "flare-cluster-production",
  "nodes": [
    {
      "name": "flare-prod-master-1",
      "container_name": "flare-prod-master-1",
      "role": "master",
      "balance": 200,
      "partition": 0
    },
    {
      "name": "flare-prod-master-2",  
      "container_name": "flare-prod-master-2",
      "role": "master",
      "balance": 200,
      "partition": 1
    },
    {
      "name": "flare-prod-slave-1",
      "container_name": "flare-prod-slave-1", 
      "role": "slave",
      "balance": 200,
      "partition": 0
    },
    {
      "name": "flare-prod-slave-2",
      "container_name": "flare-prod-slave-2",
      "role": "slave", 
      "balance": 200,
      "partition": 1
    }
  ]
}"#;

    // Staging cluster config
    let staging_config = r#"{
  "name": "flare-cluster-staging",
  "nodes": [
    {
      "name": "flare-staging-master-1",
      "container_name": "flare-staging-master-1",
      "role": "master",
      "balance": 150,
      "partition": 0
    },
    {
      "name": "flare-staging-slave-1",
      "container_name": "flare-staging-slave-1",
      "role": "slave",
      "balance": 150,
      "partition": 0
    }
  ]
}"#;

    // AWS cluster config
    let aws_config = r#"{
  "name": "flare-cluster-aws",  
  "nodes": [
    {
      "name": "flare-aws-master-1",
      "instance_id": "i-1234567890abcdef0",
      "role": "master",
      "balance": 100,
      "partition": 0
    },
    {
      "name": "flare-aws-slave-1",
      "instance_id": "i-0987654321fedcba0", 
      "role": "slave",
      "balance": 100,
      "partition": 0
    }
  ]
}"#;

    // Ensure examples directory exists
    let _ = fs::create_dir_all("examples");
    
    // Write test config files
    fs::write("examples/test-cluster-prod.json", prod_config).expect("Failed to write prod config");
    fs::write("examples/test-cluster-staging.json", staging_config).expect("Failed to write staging config");
    fs::write("examples/test-cluster-aws.json", aws_config).expect("Failed to write AWS config");
    
    println!("✓ Test configuration files created");
}

#[test]
fn test_build_flare_cluster_repl() {
    println!("Building flare-cluster-repl binary...");
    let output = Command::new("cargo")
        .args(&["build", "--bin", "flare-cluster-repl"])
        .output()
        .expect("Failed to build flare-cluster-repl");
    
    assert!(output.status.success(), "Build failed: {}", String::from_utf8_lossy(&output.stderr));
    println!("✓ flare-cluster-repl build successful");
}

#[test]
fn test_help_and_version() {
    println!("Testing help and version commands...");
    
    // Test help command
    let (success, stdout, _) = run_flare_cluster_repl(&["--help"]);
    assert!(success, "Help command should succeed");
    assert!(stdout.contains("Flare cluster replication configuration tool"), "Expected help text");
    assert!(stdout.contains("setup"), "Expected setup subcommand in help");
    assert!(stdout.contains("reload"), "Expected reload subcommand in help");
    println!("✓ Help command works");
    
    // Test version command
    let (success, stdout, _) = run_flare_cluster_repl(&["--version"]);
    assert!(success, "Version command should succeed");
    assert!(stdout.contains("1.0.0"), "Expected version number");
    println!("✓ Version command works");
}

#[test]
fn test_setup_production_cluster() {
    println!("Testing production cluster setup...");
    setup_test_configs();
    
    // Test dry-run setup for production cluster
    let (success, stdout, stderr) = run_flare_cluster_repl(&[
        "-c", "production-cluster",
        "--dry-run", 
        "-v",
        "setup",
        "-f", "examples/test-cluster-prod.json"
    ]);
    
    println!("Setup result: success={}, stderr={}", success, stderr.trim());
    assert!(success, "Production cluster setup should succeed: {}", stderr);
    
    // Verify output contains expected information
    assert!(stdout.contains("Setting up replication for cluster: flare-cluster-production"), "Expected cluster name");
    assert!(stdout.contains("Found 4 nodes in configuration"), "Expected 4 nodes");
    assert!(stdout.contains("Environment: DockerCompose"), "Expected docker-compose environment");
    assert!(stdout.contains("flare-prod-master-1"), "Expected production master container");
    assert!(stdout.contains("flare-prod-slave-1"), "Expected production slave container");
    assert!(stdout.contains("replication-enabled true"), "Expected replication enabled");
    assert!(stdout.contains("replication-role master"), "Expected master role");
    assert!(stdout.contains("replication-role slave"), "Expected slave role");
    assert!(stdout.contains("server-balance 200"), "Expected balance 200");
    assert!(stdout.contains("Would reload config using SIGHUP"), "Expected SIGHUP reload");
    
    println!("✓ Production cluster setup works correctly");
}

#[test]
fn test_setup_staging_cluster() {
    println!("Testing staging cluster setup...");
    setup_test_configs();
    
    // Test dry-run setup for staging cluster
    let (success, stdout, stderr) = run_flare_cluster_repl(&[
        "-c", "staging-cluster",
        "--dry-run",
        "-v", 
        "setup",
        "-f", "examples/test-cluster-staging.json"
    ]);
    
    assert!(success, "Staging cluster setup should succeed: {}", stderr);
    
    // Verify staging-specific configuration
    assert!(stdout.contains("Setting up replication for cluster: flare-cluster-staging"), "Expected staging cluster name");
    assert!(stdout.contains("Found 2 nodes in configuration"), "Expected 2 nodes");
    assert!(stdout.contains("flare-staging-master-1"), "Expected staging master container");
    assert!(stdout.contains("flare-staging-slave-1"), "Expected staging slave container");
    assert!(stdout.contains("server-balance 150"), "Expected balance 150");
    
    println!("✓ Staging cluster setup works correctly");
}

#[test]
fn test_different_environments() {
    println!("Testing different environment configurations...");
    setup_test_configs();
    
    // Test docker-compose environment (default)
    let (success, stdout, _) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "-e", "docker-compose",
        "--dry-run",
        "-v",
        "setup",
        "-f", "examples/test-cluster-prod.json"
    ]);
    
    assert!(success, "Docker-compose environment should work");
    assert!(stdout.contains("Environment: DockerCompose"), "Expected DockerCompose environment");
    println!("✓ Docker-compose environment works");
    
    // Test AWS environment (without AWS features enabled, should show error)
    let (success, _stdout, stderr) = run_flare_cluster_repl(&[
        "-c", "test-cluster", 
        "-e", "aws",
        "--dry-run",
        "setup",
        "-f", "examples/test-cluster-aws.json"
    ]);
    
    // Should fail because AWS features are not enabled by default
    assert!(!success, "AWS environment should fail without AWS features");
    assert!(stderr.contains("AWS support not enabled"), "Expected AWS support error");
    println!("✓ AWS environment properly requires feature flag");
}

#[test]
fn test_cluster_management_commands() {
    println!("Testing cluster management commands...");
    
    // Test status command
    let (success, stdout, _) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "--dry-run",
        "status"
    ]);
    
    assert!(success, "Status command should succeed");
    assert!(stdout.contains("Checking docker-compose cluster status"), "Expected status check message");
    assert!(stdout.contains("DRY RUN: Would execute: docker-compose ps"), "Expected docker-compose ps command");
    println!("✓ Status command works");
    
    // Test reload command
    let (success, stdout, _) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "--dry-run",
        "reload"
    ]);
    
    assert!(success, "Reload command should succeed");
    assert!(stdout.contains("Reloading docker-compose cluster configurations"), "Expected reload message");
    assert!(stdout.contains("pkill -HUP flared"), "Expected SIGHUP command");
    println!("✓ Reload command works");
    
    // Test start command
    let (success, stdout, _) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "--dry-run", 
        "start"
    ]);
    
    assert!(success, "Start command should succeed");
    assert!(stdout.contains("Starting docker-compose cluster services"), "Expected start message");
    assert!(stdout.contains("DRY RUN: Would execute: docker-compose up -d"), "Expected docker-compose up command");
    println!("✓ Start command works");
    
    // Test stop command
    let (success, stdout, _) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "--dry-run",
        "stop"
    ]);
    
    assert!(success, "Stop command should succeed");
    assert!(stdout.contains("Stopping docker-compose cluster services"), "Expected stop message");
    assert!(stdout.contains("DRY RUN: Would execute: docker-compose stop"), "Expected docker-compose stop command");
    println!("✓ Stop command works");
}

#[test]
fn test_multi_cluster_scenarios() {
    println!("Testing multi-cluster scenarios...");
    setup_test_configs();
    
    // Test production cluster
    let (success1, stdout1, _) = run_flare_cluster_repl(&[
        "-c", "production-cluster",
        "--dry-run",
        "-v",
        "setup", 
        "-f", "examples/test-cluster-prod.json"
    ]);
    
    // Test staging cluster  
    let (success2, stdout2, _) = run_flare_cluster_repl(&[
        "-c", "staging-cluster", 
        "--dry-run",
        "-v",
        "setup",
        "-f", "examples/test-cluster-staging.json"
    ]);
    
    assert!(success1 && success2, "Both cluster setups should succeed");
    
    // Verify different configurations
    assert!(stdout1.contains("server-balance 200"), "Production should have balance 200");
    assert!(stdout1.contains("Found 4 nodes"), "Production should have 4 nodes");
    
    assert!(stdout2.contains("server-balance 150"), "Staging should have balance 150");
    assert!(stdout2.contains("Found 2 nodes"), "Staging should have 2 nodes");
    
    println!("✓ Multi-cluster scenarios work correctly");
}

#[test]
fn test_error_handling() {
    println!("Testing error handling scenarios...");
    
    // Test with missing cluster name
    let (success, _stdout, stderr) = run_flare_cluster_repl(&["setup"]);
    assert!(!success, "Command without cluster name should fail");
    assert!(stderr.contains("required") || stderr.contains("cluster"), "Expected cluster name requirement error");
    println!("✓ Missing cluster name error handling works");
    
    // Test with non-existent config file
    let (success, _stdout, stderr) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "setup",
        "-f", "non-existent-file.json"
    ]);
    assert!(!success, "Command with non-existent config should fail");
    assert!(stderr.contains("Failed to read config file"), "Expected config file error");
    println!("✓ Non-existent config file error handling works");
    
    // Test with invalid JSON config
    let invalid_config = "{ invalid json }";
    fs::write("examples/invalid-config.json", invalid_config).expect("Failed to write invalid config");
    
    let (success, _stdout, stderr) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "setup",
        "-f", "examples/invalid-config.json"
    ]);
    assert!(!success, "Command with invalid JSON should fail");
    assert!(stderr.contains("Failed to parse config file"), "Expected JSON parse error");
    println!("✓ Invalid JSON error handling works");
    
    // Clean up
    let _ = fs::remove_file("examples/invalid-config.json");
}

#[test]
fn test_verbose_output() {
    println!("Testing verbose output...");
    setup_test_configs();
    
    // Test with verbose flag
    let (success, stdout, _) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "--dry-run",
        "-v",
        "setup",
        "-f", "examples/test-cluster-prod.json"
    ]);
    
    assert!(success, "Verbose command should succeed");
    
    // Verify verbose information is included
    assert!(stdout.contains("Setting up replication for cluster"), "Expected cluster setup message");
    assert!(stdout.contains("Found 4 nodes in configuration"), "Expected node count");
    assert!(stdout.contains("Environment: DockerCompose"), "Expected environment info");
    assert!(stdout.contains("Configuring container:"), "Expected container configuration messages");
    
    println!("✓ Verbose output works correctly");
}

#[test]
fn test_config_update_functionality() {
    println!("Testing configuration update functionality...");
    
    // This tests the update_flared_conf function through the binary
    // We test it by checking the dry-run output shows proper settings
    setup_test_configs();
    
    let (success, stdout, _) = run_flare_cluster_repl(&[
        "-c", "test-cluster",
        "--dry-run",
        "setup",
        "-f", "examples/test-cluster-prod.json"
    ]);
    
    assert!(success, "Config update test should succeed");
    
    // Verify all expected configuration updates are shown
    let expected_settings = [
        "replication-enabled true",
        "replication-role master", 
        "replication-role slave",
        "server-name flare-prod-master-1",
        "server-name flare-prod-slave-1",
        "server-balance 200",
        "server-partition 0", 
        "server-partition 1",
        "Would reload config using SIGHUP"
    ];
    
    for setting in &expected_settings {
        assert!(stdout.contains(setting), "Expected setting '{}' in output", setting);
    }
    
    println!("✓ Configuration update functionality works");
}

#[test]
fn test_cluster_topology_setup() {
    println!("Testing cluster topology setup with flare-admin...");
    
    // Launch multi-cluster setup
    launch_multi_cluster().expect("Failed to launch multi-cluster");
    
    // Setup cluster topology
    setup_cluster_topology();
    
    // Verify the topology with stats
    println!("Verifying cluster topology...");
    
    let (success, stdout, _) = run_flare_admin(&[
        "-i", "flarei-prod:12120",
        "stats"
    ]);
    
    assert!(success, "Should be able to get production cluster stats");
    assert!(stdout.contains("master"), "Should show master nodes");
    assert!(stdout.contains("slave"), "Should show slave nodes");
    println!("✓ Production cluster topology verified");
    
    let (success, stdout, _) = run_flare_admin(&[
        "-i", "flarei-staging:12130",
        "stats"
    ]);
    
    assert!(success, "Should be able to get staging cluster stats");
    assert!(stdout.contains("master"), "Should show master node");
    assert!(stdout.contains("slave"), "Should show slave node");
    println!("✓ Staging cluster topology verified");
    
    println!("✓ Cluster topology setup completed successfully");
    
    // Shutdown multi-cluster setup
    shutdown_multi_cluster().expect("Failed to shutdown multi-cluster");
}

#[test]
fn test_cluster_replication_with_topology() {
    println!("Testing flare-cluster-repl with established topology...");
    
    // Launch multi-cluster setup
    launch_multi_cluster().expect("Failed to launch multi-cluster");
    
    // Setup cluster topology first
    setup_cluster_topology();
    
    // Now test flare-cluster-repl
    let (success, stdout, stderr) = run_flare_cluster_repl(&[
        "-c", "flare-cluster-production",
        "-e", "docker-compose", 
        "--dry-run",
        "setup",
        "-f", "examples/cluster-prod-config.json"
    ]);
    
    if !success {
        println!("Replication setup failed - stdout: {}, stderr: {}", stdout, stderr);
    }
    
    assert!(success, "Should be able to configure replication on established cluster");
    
    // Verify replication settings would be applied
    assert!(stdout.contains("replication-enabled true"), "Should enable replication");
    assert!(stdout.contains("replication-role master"), "Should set master role");
    assert!(stdout.contains("replication-role slave"), "Should set slave role");
    assert!(stdout.contains("server-balance"), "Should set server balance");
    assert!(stdout.contains("server-partition"), "Should set server partition");
    
    println!("✓ Cluster replication configuration works with established topology");
    
    // Shutdown multi-cluster setup
    shutdown_multi_cluster().expect("Failed to shutdown multi-cluster");
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn run_all_cluster_repl_tests() {
        println!("=== Flare-Cluster-Repl Integration Test Suite ===\n");
        
        // Build first
        test_build_flare_cluster_repl();
        println!();
        
        // Basic functionality tests
        test_help_and_version();
        println!();
        
        // Cluster setup tests
        test_setup_production_cluster();
        println!();
        
        test_setup_staging_cluster(); 
        println!();
        
        // Environment tests
        test_different_environments();
        println!();
        
        // Management command tests
        test_cluster_management_commands();
        println!();
        
        // Multi-cluster tests
        test_multi_cluster_scenarios();
        println!();
        
        // Error handling tests
        test_error_handling();
        println!();
        
        // Verbose output tests
        test_verbose_output();
        println!();
        
        // Configuration functionality tests
        test_config_update_functionality();
        println!();
        
        // Note: Cluster topology and replication tests are run separately
        // as they require Docker Compose and manage their own lifecycle
        println!("💡 To run cluster topology tests: cargo test test_cluster_topology_setup -- --nocapture");
        println!("💡 To run cluster replication tests: cargo test test_cluster_replication_with_topology -- --nocapture");
        
        println!("=== Flare-Cluster-Repl Test Suite Completed ===");
        
        // Clean up test files
        let _ = fs::remove_file("examples/test-cluster-prod.json");
        let _ = fs::remove_file("examples/test-cluster-staging.json");
        let _ = fs::remove_file("examples/test-cluster-aws.json");
    }
}