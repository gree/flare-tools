use clap::{Arg, Command};
use std::process;
use std::thread;
use std::time::Duration;

use flare_tools::{FlareClient, ClientError};

fn main() {
    let matches = Command::new("flare-stats")
        .version("1.0.0")
        .about("Flare cluster statistics monitor")
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
        .arg(Arg::new("qps")
            .long("qps")
            .short('q')
            .help("Show QPS statistics")
            .action(clap::ArgAction::SetTrue))
        .arg(Arg::new("wait")
            .long("wait")
            .value_name("SECONDS")
            .help("Wait time for repeat (seconds)")
            .default_value("0"))
        .arg(Arg::new("count")
            .long("count")
            .short('c')
            .value_name("COUNT")
            .help("Repeat count")
            .default_value("1"))
        .arg(Arg::new("delimiter")
            .long("delimiter")
            .value_name("DELIMITER")
            .help("Field delimiter")
            .default_value("\t"))
        .arg(Arg::new("nodes")
            .help("Node addresses (host:port)")
            .action(clap::ArgAction::Append))
        .get_matches();

    let index_server_arg = matches.get_one::<String>("index-server").unwrap();
    let index_port_arg = matches.get_one::<String>("index-port").unwrap();
    
    // Parse index server - if it contains a port, use that instead of the port argument
    let (index_server, index_port) = if index_server_arg.contains(':') {
        parse_host_port(index_server_arg).unwrap_or_else(|e| {
            eprintln!("Invalid index server format: {}", e);
            process::exit(1);
        })
    } else {
        let port = index_port_arg.parse::<u16>()
            .unwrap_or_else(|_| {
                eprintln!("Invalid index port");
                process::exit(1);
            });
        (index_server_arg.clone(), port)
    };
    let show_qps = matches.get_flag("qps");
    let wait = matches.get_one::<String>("wait").unwrap()
        .parse::<u64>()
        .unwrap_or_else(|_| {
            eprintln!("Invalid wait time");
            process::exit(1);
        });
    let count = matches.get_one::<String>("count").unwrap()
        .parse::<u32>()
        .unwrap_or_else(|_| {
            eprintln!("Invalid count");
            process::exit(1);
        });
    let delimiter = matches.get_one::<String>("delimiter").unwrap();

    let result = run_stats(&index_server, index_port, show_qps, wait, count, delimiter);

    if let Err(e) = result {
        eprintln!("Error: {}", e);
        process::exit(1);
    }
}

fn run_stats(index_server: &str, index_port: u16, show_qps: bool, wait: u64, count: u32, delimiter: &str) -> Result<(), ClientError> {
    let mut client = FlareClient::new(index_server.to_string(), index_port);
    
    for i in 0..count {
        if i > 0 && wait > 0 {
            thread::sleep(Duration::from_secs(wait));
        }
        
        let cluster_info = client.get_stats()?;
        
        if i == 0 {
            // Print header
            if show_qps {
                println!("{node}{d}{partition}{d}{role}{d}{state}{d}{balance}{d}{items}{d}{conn}{d}{behind}{d}{hit}{d}{size}{d}{uptime}{d}{version}{d}{qps}{d}{qpsrw}",
                    node="node", partition="partition", role="role", state="state", balance="balance", items="items", conn="conn", behind="behind", hit="hit", size="size", uptime="uptime", version="version", qps="qps", qpsrw="qpsr/qpsw",
                    d = delimiter);
            } else {
                println!("{node}{d}{partition}{d}{role}{d}{state}{d}{balance}{d}{items}{d}{conn}{d}{behind}{d}{hit}{d}{size}{d}{uptime}",
                    node="node", partition="partition", role="role", state="state", balance="balance", items="items", conn="conn", behind="behind", hit="hit", size="size", uptime="uptime",
                    d = delimiter);
            }
        }
        
        for node in cluster_info.nodes {
            let partition = if node.partition >= 0 {
                node.partition.to_string()
            } else {
                "-".to_string()
            };
            
            let node_name = format!("{}:{}", node.host, node.port);
            
            if show_qps {
                println!("{node_name}{d}{partition}{d}{role}{d}{state}{d}{balance}{d}{items}{d}{conn}{d}{behind}{d}{hit:.2}{d}{size}{d}{uptime}{d}{qps:.2}{d}{qpsr:.2}/{qpsw:.2}",
                    node_name=node_name, partition=partition, role=node.role, state=node.state, balance=node.balance, 
                    items=node.items, conn=node.conn, behind=node.behind, hit=node.hit, size=node.size, 
                    uptime=node.uptime, qps=node.qps, qpsr=node.qpsr, qpsw=node.qpsw,
                    d = delimiter);
            } else {
                println!("{node_name}{d}{partition}{d}{role}{d}{state}{d}{balance}{d}{items}{d}{conn}{d}{behind}{d}{hit:.2}{d}{size}{d}{uptime}",
                    node_name=node_name, partition=partition, role=node.role, state=node.state, balance=node.balance, 
                    items=node.items, conn=node.conn, behind=node.behind, hit=node.hit, size=node.size, uptime=node.uptime,
                    d = delimiter);
            }
        }
        
        if count > 1 {
            println!(); // Empty line between iterations
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