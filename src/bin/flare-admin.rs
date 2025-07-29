use clap::{Arg, Command, ArgMatches};
use std::process;
use std::io::{self, Write};
use std::thread;
use std::time::Duration;

use flare_tools::{FlareClient, ClientError, NodeRole, NodeState, MemcachedResponse};

fn main() {
    let matches = Command::new("flare-admin")
        .version("1.0.0")
        .about("Flare cluster administration tool")
        .arg(Arg::new("index-server")
            .long("index-server")
            .short('i')
            .value_name("HOST")
            .help("Index server hostname")
            .default_value("127.0.0.1"))
        .arg(Arg::new("index-port")
            .long("index-port")
            .short('p')
            .value_name("PORT")
            .help("Index server port")
            .default_value("12120"))
        .arg(Arg::new("force")
            .long("force")
            .short('f')
            .help("Force operation without confirmation")
            .action(clap::ArgAction::SetTrue))
        .arg(Arg::new("dry-run")
            .long("dry-run")
            .help("Show what would be done without actually doing it")
            .action(clap::ArgAction::SetTrue))
        .subcommand(Command::new("ping")
            .about("Ping flare nodes")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .action(clap::ArgAction::Append)))
        .subcommand(Command::new("stats")
            .about("Show statistics of flare cluster")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .action(clap::ArgAction::Append)))
        .subcommand(Command::new("list")
            .about("List nodes in flare cluster"))
        .subcommand(Command::new("master")
            .about("Set nodes as master")
            .arg(Arg::new("nodes")
                .help("Node specs (host:port:balance:partition)")
                .required(true)
                .action(clap::ArgAction::Append))
            .arg(Arg::new("activate")
                .long("activate")
                .help("Change node's state from ready to active after setting as master")
                .action(clap::ArgAction::SetTrue))
            .arg(Arg::new("without-clean")
                .long("without-clean")
                .help("Don't clear datastore before construction (skip flush_all)")
                .action(clap::ArgAction::SetTrue)))
        .subcommand(Command::new("slave")
            .about("Set nodes as slave")
            .arg(Arg::new("nodes")
                .help("Node specs (host:port:balance:partition)")
                .required(true)
                .action(clap::ArgAction::Append)))
        .subcommand(Command::new("balance")
            .about("Set balance for nodes")
            .arg(Arg::new("nodes")
                .help("Node specs (host:port:balance)")
                .required(true)
                .action(clap::ArgAction::Append)))
        .subcommand(Command::new("down")
            .about("Set nodes down")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .required(true)
                .action(clap::ArgAction::Append)))
        .subcommand(Command::new("remove")
            .about("Remove nodes from cluster")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .required(true)
                .action(clap::ArgAction::Append)))
        .subcommand(Command::new("dump")
            .about("Dump data from nodes")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .action(clap::ArgAction::Append))
            .arg(Arg::new("all")
                .long("all")
                .help("Dump from all master nodes")
                .action(clap::ArgAction::SetTrue))
            .arg(Arg::new("output")
                .long("output")
                .short('o')
                .value_name("FILE")
                .help("Output file")))
        .subcommand(Command::new("dumpkey")
            .about("Dump keys from nodes")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .action(clap::ArgAction::Append))
            .arg(Arg::new("all")
                .long("all")
                .help("Dump from all master nodes")
                .action(clap::ArgAction::SetTrue))
            .arg(Arg::new("output")
                .long("output")
                .short('o')
                .value_name("FILE")
                .help("Output file")))
        .subcommand(Command::new("restore")
            .about("Restore data to nodes")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .required(true)
                .action(clap::ArgAction::Append))
            .arg(Arg::new("input")
                .long("input")
                .short('i')
                .value_name("FILE")
                .help("Input file")
                .required(true)))
        .subcommand(Command::new("reconstruct")
            .about("Reconstruct nodes")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .action(clap::ArgAction::Append))
            .arg(Arg::new("all")
                .long("all")
                .help("Reconstruct all nodes")
                .action(clap::ArgAction::SetTrue)))
        .subcommand(Command::new("verify")
            .about("Verify cluster consistency"))
        .subcommand(Command::new("index")
            .about("Generate index XML"))
        .subcommand(Command::new("threads")
            .about("Show thread status")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .action(clap::ArgAction::Append)))
        .subcommand(Command::new("activate")
            .about("Activate nodes (change state from ready to active)")
            .arg(Arg::new("nodes")
                .help("Node addresses (host:port)")
                .required(true)
                .action(clap::ArgAction::Append)))
        .get_matches();

    let index_server = matches.get_one::<String>("index-server").unwrap();
    let index_port = matches.get_one::<String>("index-port").unwrap()
        .parse::<u16>()
        .unwrap_or_else(|_| {
            eprintln!("Invalid index port");
            process::exit(1);
        });
    let force = matches.get_flag("force");
    let dry_run = matches.get_flag("dry-run");

    let result = match matches.subcommand() {
        Some(("ping", sub_m)) => run_ping(index_server, index_port, sub_m),
        Some(("stats", sub_m)) => run_stats(index_server, index_port, sub_m),
        Some(("list", sub_m)) => run_list(index_server, index_port, sub_m),
        Some(("master", sub_m)) => run_master(index_server, index_port, sub_m, force, dry_run),
        Some(("slave", sub_m)) => run_slave(index_server, index_port, sub_m, force, dry_run),
        Some(("balance", sub_m)) => run_balance(index_server, index_port, sub_m, force, dry_run),
        Some(("down", sub_m)) => run_down(index_server, index_port, sub_m, force, dry_run),
        Some(("remove", sub_m)) => run_remove(index_server, index_port, sub_m, force, dry_run),
        Some(("dump", sub_m)) => run_dump(index_server, index_port, sub_m, dry_run),
        Some(("dumpkey", sub_m)) => run_dumpkey(index_server, index_port, sub_m, dry_run),
        Some(("restore", sub_m)) => run_restore(index_server, index_port, sub_m, dry_run),
        Some(("reconstruct", sub_m)) => run_reconstruct(index_server, index_port, sub_m, force, dry_run),
        Some(("verify", sub_m)) => run_verify(index_server, index_port, sub_m),
        Some(("index", sub_m)) => run_index(index_server, index_port, sub_m),
        Some(("threads", sub_m)) => run_threads(index_server, index_port, sub_m),
        Some(("activate", sub_m)) => run_activate(index_server, index_port, sub_m, force, dry_run),
        _ => {
            eprintln!("No subcommand specified. Use --help for usage information.");
            process::exit(1);
        }
    };

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        process::exit(1);
    }
}

fn run_ping(index_server: &str, index_port: u16, matches: &ArgMatches) -> Result<(), ClientError> {
    let nodes: Vec<String> = if let Some(node_values) = matches.get_many::<String>("nodes") {
        node_values.cloned().collect()
    } else {
        vec![format!("{}:{}", index_server, index_port)]
    };

    let mut failed_count = 0;

    for node in nodes {
        let (host, port) = parse_host_port(&node)?;
        let mut client = FlareClient::new(host.clone(), port);
        
        match client.ping() {
            Ok(()) => println!("alive: {}:{}", host, port),
            Err(e) => {
                eprintln!("ping failed for {}:{}: {}", host, port, e);
                failed_count += 1;
            }
        }
    }
    
    if failed_count > 0 {
        return Err(ClientError::InvalidResponse(format!("{} ping(s) failed", failed_count)));
    }
    
    Ok(())
}

fn run_stats(index_server: &str, index_port: u16, _matches: &ArgMatches) -> Result<(), ClientError> {
    let mut client = FlareClient::new(index_server.to_string(), index_port);
    let cluster_info = client.get_stats()?;
    
    println!("{:<30} {:<10} {:<10} {:<10} {:<7}", "node", "partition", "role", "state", "balance");
    
    for node in cluster_info.nodes {
        let partition = if node.partition >= 0 {
            node.partition.to_string()
        } else {
            "-".to_string()
        };
        
        println!("{:<30} {:<10} {:<10} {:<10} {:<7}",
            format!("{}:{}", node.host, node.port),
            partition,
            node.role,
            node.state,
            node.balance
        );
    }
    
    Ok(())
}

fn run_list(index_server: &str, index_port: u16, _matches: &ArgMatches) -> Result<(), ClientError> {
    run_stats(index_server, index_port, _matches)
}

fn run_master(index_server: &str, index_port: u16, matches: &ArgMatches, force: bool, dry_run: bool) -> Result<(), ClientError> {
    let nodes: Vec<String> = matches.get_many::<String>("nodes")
        .unwrap()
        .cloned()
        .collect();
    
    let activate = matches.get_flag("activate");
    let without_clean = matches.get_flag("without-clean");

    if !force && !dry_run {
        let clean_notice = if without_clean {
            ""
        } else {
            "\nitems stored in the node will be cleaned up (exec flush_all) before constructing it"
        };
        print!("This will set {} nodes as master{} (y/n): ", nodes.len(), clean_notice);
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Operation canceled");
            return Ok(());
        }
    }

    let mut client = FlareClient::new(index_server.to_string(), index_port);
    
    for node_spec in nodes {
        let parts: Vec<&str> = node_spec.split(':').collect();
        if parts.len() != 4 {
            return Err(ClientError::InvalidResponse(
                format!("Invalid node spec: {} (expected host:port:balance:partition)", node_spec)
            ));
        }
        
        let host = parts[0].to_string();
        let port = parts[1].parse::<u16>()
            .map_err(|_| ClientError::InvalidResponse("Invalid port".to_string()))?;
        let balance = parts[2].parse::<i32>()
            .map_err(|_| ClientError::InvalidResponse("Invalid balance".to_string()))?;
        let partition = parts[3].parse::<i32>()
            .map_err(|_| ClientError::InvalidResponse("Invalid partition".to_string()))?;

        if dry_run {
            println!("DRY RUN: Would set {}:{} as master with balance={}, partition={}", host, port, balance, partition);
            if activate {
                println!("DRY RUN: Would activate {}:{} after construction", host, port);
            }
        } else {
            // First flush_all (unless skipped)
            if !without_clean {
                let mut node_client = FlareClient::new(host.clone(), port);
                node_client.flush_all()?;
                println!("executed flush_all command before constructing the master node.");
            }
            
            // Set role with retry logic (simplified version)
            let mut retry_count = 0;
            let max_retries = 10;
            let mut success = false;
            
            while !success && retry_count < max_retries {
                match client.set_node_role(host.clone(), port, NodeRole::Master, balance, Some(partition)) {
                    Ok(()) => {
                        success = true;
                        println!("started constructing the master node...");
                    }
                    Err(e) => {
                        retry_count += 1;
                        if retry_count < max_retries {
                            println!("waiting {} sec...", retry_count);
                            std::thread::sleep(std::time::Duration::from_secs(retry_count as u64));
                            println!("retrying...");
                        } else {
                            return Err(e);
                        }
                    }
                }
            }
            
            if success {
                println!("Set {}:{} as master", host, port);
                
                // If activate flag is set, wait for ready state and then activate
                if activate {
                    // Simple implementation - in Ruby there's a wait_for_master_construction function
                    std::thread::sleep(std::time::Duration::from_secs(2)); // Give time for construction
                    
                    if !force {
                        print!("changing node's state (node={}:{}, state=ready -> active) (y/n): ", host, port);
                        io::stdout().flush().unwrap();
                        let mut input = String::new();
                        io::stdin().read_line(&mut input).unwrap();
                        if !input.trim().eq_ignore_ascii_case("y") {
                            continue;
                        }
                    }
                    
                    match client.set_node_state(host.clone(), port, NodeState::Active) {
                        Ok(()) => println!("Activated {}:{}", host, port),
                        Err(e) => {
                            eprintln!("failed to activate {}:{}: {}", host, port, e);
                            return Err(e);
                        }
                    }
                }
            }
        }
    }
    
    Ok(())
}

fn run_slave(index_server: &str, index_port: u16, matches: &ArgMatches, force: bool, dry_run: bool) -> Result<(), ClientError> {
    let nodes: Vec<String> = matches.get_many::<String>("nodes")
        .unwrap()
        .cloned()
        .collect();

    if !force && !dry_run {
        print!("This will set {} nodes as slave. Continue? (y/n): ", nodes.len());
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Operation canceled");
            return Ok(());
        }
    }

    let mut client = FlareClient::new(index_server.to_string(), index_port);
    
    for node_spec in nodes {
        let parts: Vec<&str> = node_spec.split(':').collect();
        if parts.len() != 4 {
            return Err(ClientError::InvalidResponse(
                format!("Invalid node spec: {} (expected host:port:balance:partition)", node_spec)
            ));
        }
        
        let host = parts[0].to_string();
        let port = parts[1].parse::<u16>()
            .map_err(|_| ClientError::InvalidResponse("Invalid port".to_string()))?;
        let balance = parts[2].parse::<i32>()
            .map_err(|_| ClientError::InvalidResponse("Invalid balance".to_string()))?;
        let partition = parts[3].parse::<i32>()
            .map_err(|_| ClientError::InvalidResponse("Invalid partition".to_string()))?;

        if dry_run {
            println!("DRY RUN: Would set {}:{} as slave with balance={}, partition={}", host, port, balance, partition);
        } else {
            // First flush_all
            let mut node_client = FlareClient::new(host.clone(), port);
            node_client.flush_all()?;
            
            // Then set role
            client.set_node_role(host.clone(), port, NodeRole::Slave, balance, Some(partition))?;
            println!("Set {}:{} as slave", host, port);
        }
    }
    
    Ok(())
}

fn run_balance(_index_server: &str, _index_port: u16, matches: &ArgMatches, force: bool, dry_run: bool) -> Result<(), ClientError> {
    let nodes: Vec<String> = matches.get_many::<String>("nodes")
        .unwrap()
        .cloned()
        .collect();

    if !force && !dry_run {
        print!("This will change balance for {} nodes. Continue? (y/n): ", nodes.len());
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Operation canceled");
            return Ok(());
        }
    }


    if dry_run {
        println!("DRY RUN MODE - no actual changes will be made");
        for node_spec in nodes {
            println!("Would set balance for: {}", node_spec);
        }
        println!("Operation completed successfully");
        return Ok(());
    }

    // Implementation would need to get current role/partition info and update balance
    // This is a simplified version
    println!("Balance setting not fully implemented yet");
    
    Ok(())
}

fn run_down(index_server: &str, index_port: u16, matches: &ArgMatches, force: bool, dry_run: bool) -> Result<(), ClientError> {
    let nodes: Vec<String> = matches.get_many::<String>("nodes")
        .unwrap()
        .cloned()
        .collect();

    if !force && !dry_run {
        print!("This will turn down {} nodes. Continue? (y/n): ", nodes.len());
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Operation canceled");
            return Ok(());
        }
    }

    println!("Turning down nodes...");

    if dry_run {
        println!("DRY RUN MODE - no actual changes will be made");
        for node in &nodes {
            println!("Would turn down node: {}", node);
        }
        println!("Operation completed successfully");
        return Ok(());
    }

    let mut client = FlareClient::new(index_server.to_string(), index_port);
    
    for node in nodes {
        let (host, port) = parse_host_port(&node)?;
        client.set_node_state(host.clone(), port, NodeState::Down)?;
        println!("Set {}:{} as down", host, port);
    }
    
    Ok(())
}

fn run_remove(index_server: &str, index_port: u16, matches: &ArgMatches, force: bool, dry_run: bool) -> Result<(), ClientError> {
    let nodes: Vec<String> = matches.get_many::<String>("nodes")
        .unwrap()
        .cloned()
        .collect();

    if !force && !dry_run {
        print!("This will remove {} nodes. Continue? (y/n): ", nodes.len());
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Operation canceled");
            return Ok(());
        }
    }

    println!("Removing nodes...");

    if dry_run {
        println!("DRY RUN MODE - no actual changes will be made");
        for node in &nodes {
            println!("Would remove node: {}", node);
        }
        println!("Operation completed successfully");
        return Ok(());
    }

    let mut client = FlareClient::new(index_server.to_string(), index_port);
    
    for node in nodes {
        let (host, port) = parse_host_port(&node)?;
        client.remove_node(host.clone(), port)?;
        println!("Removed {}:{}", host, port);
    }
    
    Ok(())
}

fn run_dump(index_server: &str, index_port: u16, matches: &ArgMatches, dry_run: bool) -> Result<(), ClientError> {
    let all = matches.get_flag("all");
    let output = matches.get_one::<String>("output");
    
    let nodes: Vec<String> = if all {
        // Get all master nodes from cluster
        let mut client = FlareClient::new(index_server.to_string(), index_port);
        let cluster_info = client.get_stats()?;
        cluster_info.nodes.into_iter()
            .filter(|node| node.role == "master")
            .map(|node| format!("{}:{}", node.host, node.port))
            .collect()
    } else if let Some(node_values) = matches.get_many::<String>("nodes") {
        node_values.cloned().collect()
    } else {
        return Err(ClientError::InvalidResponse("No nodes specified and --all not used".to_string()));
    };

    let target = if all { "all master nodes" } else { "specified nodes" };
    println!("Dumping data from {}...", target);

    if dry_run {
        println!("DRY RUN MODE - no actual dump will be performed");
        for node in &nodes {
            println!("Would dump data from: {}", node);
        }
        println!("Dump completed successfully");
        return Ok(());
    }

    let mut all_data = Vec::new();
    
    for node in nodes {
        let (host, port) = parse_host_port(&node)?;
        let mut client = FlareClient::new(host, port);
        let data = client.dump_data_full(None, None, None, None)?;
        
        for response in data {
            if let MemcachedResponse::Value { key, flags, bytes, cas_unique, exptime, data } = response {
                let value_line = match (cas_unique, exptime) {
                    (Some(cas), Some(exp)) => format!("VALUE {} {} {} {} {}", key, flags, bytes, cas, exp),
                    (Some(cas), None) => format!("VALUE {} {} {} {}", key, flags, bytes, cas),
                    (None, Some(exp)) => format!("VALUE {} {} {} {}", key, flags, bytes, exp),
                    (None, None) => format!("VALUE {} {} {}", key, flags, bytes),
                };
                all_data.push(format!("{}\r\n{}", value_line, String::from_utf8_lossy(&data)));
            }
        }
    }

    if let Some(output_file) = output {
        std::fs::write(output_file, all_data.join("\r\n"))
            .map_err(|e| ClientError::InvalidResponse(format!("Failed to write output file: {}", e)))?;
        println!("Dump saved to {}", output_file);
    } else {
        for line in all_data {
            println!("{}", line);
        }
    }

    Ok(())
}

fn run_dumpkey(index_server: &str, index_port: u16, matches: &ArgMatches, dry_run: bool) -> Result<(), ClientError> {
    let all = matches.get_flag("all");
    let output = matches.get_one::<String>("output");
    
    let nodes: Vec<String> = if all {
        // Get all master nodes from cluster
        let mut client = FlareClient::new(index_server.to_string(), index_port);
        let cluster_info = client.get_stats()?;
        cluster_info.nodes.into_iter()
            .filter(|node| node.role == "master")
            .map(|node| format!("{}:{}", node.host, node.port))
            .collect()
    } else if let Some(node_values) = matches.get_many::<String>("nodes") {
        node_values.cloned().collect()
    } else {
        return Err(ClientError::InvalidResponse("No nodes specified and --all not used".to_string()));
    };

    let target = if all { "all partitions" } else { "specified nodes" };
    println!("Dumping keys from {}...", target);

    if dry_run {
        println!("DRY RUN MODE - no actual dump will be performed");
        for node in &nodes {
            println!("Would dump keys from: {}", node);
        }
        println!("Key dump completed successfully");
        return Ok(());
    }

    let mut all_keys = Vec::new();
    
    for node in nodes {
        let (host, port) = parse_host_port(&node)?;
        let mut client = FlareClient::new(host, port);
        let keys = client.dump_keys(None, None)?;
        all_keys.extend(keys);
    }

    if let Some(output_file) = output {
        let content = all_keys.join("\n");
        std::fs::write(output_file, content)
            .map_err(|e| ClientError::InvalidResponse(format!("Failed to write output file: {}", e)))?;
        println!("Keys saved to {}", output_file);
    } else {
        for key in all_keys {
            println!("{}", key);
        }
    }

    Ok(())
}

fn run_restore(_index_server: &str, _index_port: u16, matches: &ArgMatches, dry_run: bool) -> Result<(), ClientError> {
    let nodes: Vec<String> = matches.get_many::<String>("nodes")
        .unwrap()
        .cloned()
        .collect();
    
    let input_file = matches.get_one::<String>("input").unwrap();

    // Read the dump file
    let data = std::fs::read_to_string(input_file)
        .map_err(|e| ClientError::Io(e))?;

    println!("Restoring data to {} nodes from {}...", nodes.len(), input_file);

    if dry_run {
        println!("DRY RUN MODE - no actual restore will be performed");
        let lines: Vec<&str> = data.lines().collect();
        let mut count = 0;
        let mut i = 0;
        while i < lines.len() {
            let line = lines[i].trim();
            if line.starts_with("VALUE ") {
                count += 1;
                i += 2; // Skip the data line
            } else {
                i += 1;
            }
        }
        println!("Would restore {} items", count);
        return Ok(());
    }

    for node in nodes {
        let (host, port) = parse_host_port(&node)?;
        let mut client = FlareClient::new(host.clone(), port);
        
        let mut restored_count = 0;
        let mut error_count = 0;
        
        let lines: Vec<&str> = data.lines().collect();
        let mut i = 0;
        
        while i < lines.len() {
            let line = lines[i].trim();
            
            // Skip empty lines and END markers
            if line.is_empty() || line == "END" {
                i += 1;
                continue;
            }
            
            // Handle VALUE lines: "VALUE key flags bytes [version] [expiration]"
            if line.starts_with("VALUE ") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() < 4 {
                    error_count += 1;
                    i += 1;
                    continue;
                }
                
                let key = parts[1];
                let flags = parts[2].parse::<u32>().unwrap_or(0);
                let bytes_len = parts[3].parse::<usize>().unwrap_or(0);
                // In dump format: VALUE key flags bytes version exptime
                // parts[4] is version, parts[5] is exptime
                let exptime = if parts.len() >= 6 {
                    parts[5].parse::<u32>().unwrap_or(0)
                } else if parts.len() >= 5 {
                    // Handle case where there's no exptime (only version)
                    0
                } else {
                    0
                };
                
                // Get the data value from next line
                i += 1;
                if i >= lines.len() {
                    error_count += 1;
                    break;
                }
                
                let value = lines[i];
                let data_bytes = if value.len() > bytes_len {
                    &value.as_bytes()[..bytes_len]
                } else {
                    value.as_bytes()
                };
                
                // Send set command to restore the key
                match client.set_key_value(key, flags, exptime, data_bytes) {
                    Ok(()) => {
                        restored_count += 1;
                    }
                    Err(e) => {
                        error_count += 1;
                        println!("Failed to restore key {}: {}", key, e);
                    }
                }
            }
            i += 1;
        }
        
        println!("Restored {} items to {}:{} ({} errors)", restored_count, host, port, error_count);
    }

    println!("Restore completed successfully");
    Ok(())
}

fn run_reconstruct(index_server: &str, index_port: u16, matches: &ArgMatches, force: bool, dry_run: bool) -> Result<(), ClientError> {
    let all = matches.get_flag("all");
    let retry_count = matches.get_one::<String>("retry")
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or(10);
    
    // Get nodes to reconstruct
    let nodes: Vec<String> = if all {
        // Get all master and slave nodes from cluster
        let mut client = FlareClient::new(index_server.to_string(), index_port);
        let cluster_info = client.get_stats()?;
        cluster_info.nodes.into_iter()
            .filter(|node| node.role == "master" || node.role == "slave")
            .map(|node| format!("{}:{}", node.host, node.port))
            .collect()
    } else if let Some(node_values) = matches.get_many::<String>("nodes") {
        node_values.cloned().collect()
    } else {
        return Err(ClientError::InvalidResponse("No nodes specified and --all not used".to_string()));
    };

    if nodes.is_empty() {
        println!("No nodes to reconstruct");
        return Ok(());
    }

    // Get cluster info for node details
    let mut index_client = FlareClient::new(index_server.to_string(), index_port);
    let cluster_info = index_client.get_stats()?;
    
    if !force && !dry_run {
        print!("This will reconstruct {} nodes. Continue? (y/n): ", nodes.len());
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("Operation canceled");
            return Ok(());
        }
    }

    println!("Reconstructing {} nodes...", nodes.len());

    if dry_run {
        println!("DRY RUN MODE - no actual changes will be made");
        for node in &nodes {
            println!("Would reconstruct node: {}", node);
        }
        println!("Operation completed successfully");
        return Ok(());
    }

    for node_spec in nodes {
        let (host, port) = parse_host_port(&node_spec)?;
        
        // Find node info
        let node_info = cluster_info.nodes.iter()
            .find(|n| n.host == host && n.port == port)
            .ok_or_else(|| ClientError::InvalidResponse(format!("{} is not found in this cluster", node_spec)))?;
        
        let current_role = node_info.role.clone();
        let current_balance = node_info.balance;
        let partition = node_info.partition;
        
        println!("Reconstructing node {}:{} (role={}, partition={})", host, port, current_role, partition);
        
        // Step 1: Set node state to down
        println!("  Setting node state to down...");
        index_client.set_node_state(host.clone(), port, NodeState::Down)?;
        
        // Step 2: Wait for node to be active again
        println!("  Waiting for node to be active again...");
        thread::sleep(Duration::from_secs(3));
        
        // Step 3: Connect to the node and flush_all
        println!("  Flushing all data on the node...");
        let mut node_client = FlareClient::new(host.clone(), port);
        node_client.flush_all()?;
        
        // Step 4: Set the role to slave with retry logic
        let mut success = false;
        for attempt in 0..retry_count {
            println!("  Setting node role to slave (attempt {}/{})", attempt + 1, retry_count);
            
            match index_client.set_node_role(host.clone(), port, NodeRole::Slave, 0, Some(partition)) {
                Ok(()) => {
                    println!("  Started constructing node as slave...");
                    success = true;
                    break;
                }
                Err(e) => {
                    if attempt < retry_count - 1 {
                        let wait_time = attempt + 1;
                        println!("  Failed: {}. Waiting {} seconds before retry...", e, wait_time);
                        thread::sleep(Duration::from_secs(wait_time as u64));
                    } else {
                        return Err(ClientError::InvalidResponse(format!("Failed to set role after {} attempts: {}", retry_count, e)));
                    }
                }
            }
        }
        
        if success {
            // Step 5: Wait for slave construction to complete
            println!("  Waiting for slave construction to complete...");
            wait_for_slave_construction(&mut index_client, &host, port, Duration::from_secs(30))?;
            
            // Step 6: Restore the original balance if it was non-zero
            if current_balance > 0 {
                if !force {
                    print!("  Restore balance to {} for {}? (y/n): ", current_balance, node_spec);
                    io::stdout().flush().unwrap();
                    let mut input = String::new();
                    io::stdin().read_line(&mut input).unwrap();
                    if !input.trim().eq_ignore_ascii_case("y") {
                        println!("  Skipping balance restoration");
                        continue;
                    }
                }
                println!("  Restoring balance to {}", current_balance);
                index_client.set_node_role(host.clone(), port, NodeRole::Slave, current_balance, Some(partition))?;
            }
            
            println!("  Reconstruction of {} completed successfully", node_spec);
        }
    }
    
    println!("\nReconstruction completed successfully");
    Ok(())
}

fn run_verify(index_server: &str, index_port: u16, _matches: &ArgMatches) -> Result<(), ClientError> {
    println!("Verifying cluster consistency...");
    
    let mut client = FlareClient::new(index_server.to_string(), index_port);
    let cluster_info = client.get_stats()?;
    
    let mut errors = 0;
    let mut warnings = 0;
    
    // Check for basic cluster health
    if cluster_info.nodes.is_empty() {
        println!("ERROR: No nodes found in cluster");
        return Err(ClientError::InvalidResponse("No nodes found in cluster".to_string()));
    }
    
    println!("Found {} nodes in cluster", cluster_info.nodes.len());
    
    // Check node states and roles
    let mut master_count = 0;
    let mut active_count = 0;
    let mut partitions = std::collections::HashMap::new();
    
    for node in &cluster_info.nodes {
        println!("Checking node {}:{}...", node.host, node.port);
        
        // Test connectivity
        let mut node_client = FlareClient::new(node.host.clone(), node.port);
        match node_client.ping() {
            Ok(()) => println!("  ✓ Node is reachable"),
            Err(e) => {
                println!("  ✗ Node is unreachable: {}", e);
                errors += 1;
                continue;
            }
        }
        
        // Check role
        match node.role.as_str() {
            "master" => {
                master_count += 1;
                println!("  ✓ Node is master");
            }
            "slave" => println!("  ✓ Node is slave"),
            "proxy" => println!("  ✓ Node is proxy"),
            _ => {
                println!("  ⚠ Node has unknown role: {}", node.role);
                warnings += 1;
            }
        }
        
        // Check state
        match node.state.as_str() {
            "active" => {
                active_count += 1;
                println!("  ✓ Node is active");
            }
            "prepare" => {
                println!("  ⚠ Node is in prepare state");
                warnings += 1;
            }
            "down" => {
                println!("  ✗ Node is down");
                errors += 1;
            }
            _ => {
                println!("  ⚠ Node has unknown state: {}", node.state);
                warnings += 1;
            }
        }
        
        // Track partitions
        if node.role == "master" && node.partition >= 0 {
            let partition_key = node.partition;
            partitions.entry(partition_key)
                .and_modify(|count| *count += 1)
                .or_insert(1);
        }
        
        // Check balance
        if node.balance <= 0 && (node.role == "master" || node.role == "slave") {
            println!("  ⚠ Node has zero or negative balance: {}", node.balance);
            warnings += 1;
        }
    }
    
    // Verify partition distribution
    println!("\nPartition analysis:");
    if partitions.is_empty() {
        println!("  ⚠ No partitions assigned to master nodes");
        warnings += 1;
    } else {
        for (partition, count) in &partitions {
            if *count > 1 {
                println!("  ✗ Partition {} assigned to {} masters (should be 1)", partition, count);
                errors += 1;
            } else {
                println!("  ✓ Partition {} properly assigned", partition);
            }
        }
    }
    
    // Summary
    println!("\nVerification Summary:");
    println!("  Total nodes: {}", cluster_info.nodes.len());
    println!("  Master nodes: {}", master_count);
    println!("  Active nodes: {}", active_count);
    println!("  Partitions: {}", partitions.len());
    println!("  Errors: {}", errors);
    println!("  Warnings: {}", warnings);
    
    if errors == 0 && warnings == 0 {
        println!("\n✓ Cluster verification completed successfully - no issues found");
        Ok(())
    } else if errors == 0 {
        println!("\n⚠ Cluster verification completed with {} warnings", warnings);
        Ok(())
    } else {
        println!("\n✗ Cluster verification failed with {} errors and {} warnings", errors, warnings);
        Err(ClientError::InvalidResponse(format!("Cluster verification failed with {} errors", errors)))
    }
}

fn run_index(index_server: &str, index_port: u16, _matches: &ArgMatches) -> Result<(), ClientError> {
    println!("Generating index XML...");
    
    let mut client = FlareClient::new(index_server.to_string(), index_port);
    let xml = client.generate_index_xml()?;
    
    println!("{}", xml);
    Ok(())
}

fn run_threads(index_server: &str, index_port: u16, matches: &ArgMatches) -> Result<(), ClientError> {
    let nodes: Vec<String> = if let Some(node_values) = matches.get_many::<String>("nodes") {
        node_values.cloned().collect()
    } else {
        // Default to index server
        vec![format!("{}:{}", index_server, index_port)]
    };

    for node in nodes {
        let (host, port) = parse_host_port(&node)?;
        println!("Getting thread status for {}:{}...", host, port);
        
        let mut client = FlareClient::new(host.clone(), port);
        match client.get_thread_status() {
            Ok(stats) => {
                println!("Thread status for {}:{}:", host, port);
                for stat in stats {
                    println!("{}", stat);
                }
                println!("END\n");
            }
            Err(e) => {
                println!("Failed to get thread status from {}:{}: {}", host, port, e);
            }
        }
    }
    
    Ok(())
}

fn run_activate(index_server: &str, index_port: u16, matches: &ArgMatches, force: bool, dry_run: bool) -> Result<(), ClientError> {
    let nodes: Vec<String> = matches.get_many::<String>("nodes")
        .unwrap()
        .cloned()
        .collect();

    let mut client = FlareClient::new(index_server.to_string(), index_port);
    
    // Get current cluster state to check node states
    let cluster_info = client.get_stats()?;
    
    for node_spec in nodes {
        let (host, port) = parse_host_port(&node_spec)?;
        
        // Find the node in cluster info
        let node_info = cluster_info.nodes.iter()
            .find(|n| n.host == host && n.port == port);
            
        match node_info {
            Some(node) => {
                if !force && !dry_run {
                    if node.state == "active" {
                        println!("{}:{} is already active.", host, port);
                        continue;
                    } else {
                        print!("turning node up (node={}:{}, state={} -> active) (y/n): ", host, port, node.state);
                        io::stdout().flush().unwrap();
                        let mut input = String::new();
                        io::stdin().read_line(&mut input).unwrap();
                        if !input.trim().eq_ignore_ascii_case("y") {
                            println!("Skipping {}:{}", host, port);
                            continue;
                        }
                    }
                }
                
                if dry_run {
                    println!("DRY RUN: Would activate {}:{} (current state: {})", host, port, node.state);
                } else {
                    // Retry logic similar to Ruby implementation
                    let mut success = false;
                    let max_retries = if force { 1 } else { 3 };
                    
                    for attempt in 1..=max_retries {
                        match client.set_node_state(host.clone(), port, NodeState::Active) {
                            Ok(()) => {
                                println!("Activated {}:{}", host, port);
                                success = true;
                                break;
                            }
                            Err(e) => {
                                if attempt == max_retries {
                                    eprintln!("failed to activate {}:{}: {}", host, port, e);
                                    return Err(e);
                                } else if !force {
                                    eprintln!("Attempt {} failed, retrying...", attempt);
                                    print!("turning node up (node={}:{}, state={} -> active) (y/n): ", host, port, node.state);
                                    io::stdout().flush().unwrap();
                                    let mut input = String::new();
                                    io::stdin().read_line(&mut input).unwrap();
                                    if !input.trim().eq_ignore_ascii_case("y") {
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    
                    if !success && !force {
                        println!("Failed to activate {}:{} after {} attempts", host, port, max_retries);
                    }
                }
            }
            None => {
                eprintln!("invalid 'hostname:port' pair: {}:{}", host, port);
                return Err(ClientError::InvalidResponse(format!("Node {}:{} not found in cluster", host, port)));
            }
        }
    }
    
    // Show updated cluster state
    if !dry_run {
        println!("\nUpdated cluster state:");
        let updated_cluster = client.get_stats()?;
        println!("{:<30} {:<10} {:<10} {:<10} {:<7}", "node", "partition", "role", "state", "balance");
        for node in updated_cluster.nodes {
            let partition = if node.partition >= 0 {
                node.partition.to_string()
            } else {
                "-".to_string()
            };
            println!("{:<30} {:<10} {:<10} {:<10} {:<7}", 
                format!("{}:{}", node.host, node.port), 
                partition, 
                node.role, 
                node.state, 
                node.balance
            );
        }
    }
    
    Ok(())
}

fn parse_host_port(node: &str) -> Result<(String, u16), ClientError> {
    let parts: Vec<&str> = node.split(':').collect();
    if parts.len() != 2 {
        return Err(ClientError::InvalidResponse(format!("Invalid host:port format: {}", node)));
    }
    
    let host = parts[0].to_string();
    let port = parts[1].parse::<u16>()
        .map_err(|_| ClientError::InvalidResponse(format!("Invalid port: {}", parts[1])))?;
    
    Ok((host, port))
}

fn wait_for_active_state(client: &mut FlareClient, host: &str, port: u16, timeout: Duration) -> Result<(), ClientError> {
    let start_time = std::time::Instant::now();
    
    loop {
        if start_time.elapsed() > timeout {
            return Err(ClientError::InvalidResponse(format!("Timeout waiting for {}:{} to become active", host, port)));
        }
        
        match client.get_stats() {
            Ok(cluster_info) => {
                for node in &cluster_info.nodes {
                    if node.host == host && node.port == port {
                        if node.state == "active" {
                            return Ok(());
                        }
                        break;
                    }
                }
            }
            Err(_) => {}
        }
        
        thread::sleep(Duration::from_secs(1));
    }
}

fn wait_for_slave_construction(client: &mut FlareClient, host: &str, port: u16, timeout: Duration) -> Result<(), ClientError> {
    let start_time = std::time::Instant::now();
    
    loop {
        if start_time.elapsed() > timeout {
            return Err(ClientError::InvalidResponse(format!("Timeout waiting for slave construction on {}:{}", host, port)));
        }
        
        match client.get_stats() {
            Ok(cluster_info) => {
                for node in &cluster_info.nodes {
                    if node.host == host && node.port == port {
                        if node.role == "slave" && node.state == "active" {
                            return Ok(());
                        }
                        break;
                    }
                }
            }
            Err(_) => {}
        }
        
        thread::sleep(Duration::from_secs(1));
    }
}
