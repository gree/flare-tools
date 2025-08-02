use std::io::{self, BufRead, BufReader, Write};
use std::net::{TcpStream, SocketAddr, ToSocketAddrs};
use std::time::Duration;
use thiserror::Error;

use crate::protocol::{FlareCommand, FlareError, FlareParser, FlareResponse, MemcachedCommand, MemcachedResponse};

#[derive(Debug, Error)]
pub enum ClientError {
    #[error("IO error: {0}")]
    Io(io::Error),
    #[error("Protocol error: {0}")]
    Protocol(#[from] FlareError),
    #[error("Connection timeout")]
    Timeout,
    #[error("Invalid response: {0}")]
    InvalidResponse(String),
}

pub struct FlareClient {
    stream: Option<TcpStream>,
    host: String,
    port: u16,
}

#[derive(Debug, Clone)]
pub struct NodeInfo {
    pub host: String,
    pub port: u16,
    pub role: String,
    pub state: String,
    pub partition: i32,
    pub balance: i32,
    pub items: u64,
    pub conn: u32,
    pub behind: u64,
    pub hit: f64,
    pub size: u64,
    pub uptime: String,
    pub version: String,
    pub qps: f64,
    pub qpsr: f64,
    pub qpsw: f64,
}

#[derive(Debug, Clone)]
pub struct ClusterInfo {
    pub nodes: Vec<NodeInfo>,
}

impl FlareClient {
    pub fn new(host: String, port: u16) -> Self {
        FlareClient {
            stream: None,
            host,
            port,
        }
    }

    pub fn connect(&mut self) -> Result<(), ClientError> {
        let addr_str = format!("{}:{}", self.host, self.port);
        
        // Resolve hostname to socket addresses
        let addrs: Vec<SocketAddr> = addr_str.to_socket_addrs()
            .map_err(|e| ClientError::InvalidResponse(format!("Failed to resolve {}: {}", addr_str, e)))?
            .collect();
        
        if addrs.is_empty() {
            return Err(ClientError::InvalidResponse(format!("No addresses found for {}", addr_str)));
        }
        
        // Try to connect to the first resolved address with shorter timeout
        let stream = TcpStream::connect_timeout(&addrs[0], Duration::from_secs(3))
            .map_err(|e| {
                match e.kind() {
                    io::ErrorKind::ConnectionRefused => {
                        ClientError::InvalidResponse(format!("Connection refused to {}: Service may not be running", addr_str))
                    }
                    io::ErrorKind::TimedOut => {
                        ClientError::InvalidResponse(format!("Connection timeout to {}: Service may not be reachable", addr_str))
                    }
                    io::ErrorKind::WouldBlock | io::ErrorKind::AddrNotAvailable => {
                        ClientError::InvalidResponse(format!("Connection failed to {}: Service may not be available", addr_str))
                    }
                    _ => ClientError::InvalidResponse(format!("Failed to connect to {}: {} ({:?})", addr_str, e, e.kind()))
                }
            })?;
        stream.set_read_timeout(Some(Duration::from_secs(30)))
            .map_err(ClientError::Io)?;
        stream.set_write_timeout(Some(Duration::from_secs(30)))
            .map_err(ClientError::Io)?;
        stream.set_nonblocking(false)
            .map_err(ClientError::Io)?;
        
        self.stream = Some(stream);
        Ok(())
    }

    pub fn disconnect(&mut self) -> Result<(), ClientError> {
        if let Some(mut stream) = self.stream.take() {
            // Send quit command gracefully
            let _ = stream.write_all(b"quit\r\n");
            let _ = stream.shutdown(std::net::Shutdown::Both);
        }
        Ok(())
    }

    pub fn send_command(&mut self, command: &FlareCommand) -> Result<Vec<FlareResponse>, ClientError> {
        if self.stream.is_none() {
            self.connect()?;
        }

        let stream = self.stream.as_mut().unwrap();
        let cmd_bytes = FlareParser::format_command(command);
        
        stream.write_all(&cmd_bytes)
            .map_err(ClientError::Io)?;
        stream.flush()
            .map_err(ClientError::Io)?;

        self.read_responses()
    }

    fn read_responses(&mut self) -> Result<Vec<FlareResponse>, ClientError> {
        let stream = self.stream.as_ref().unwrap();
        let mut reader = BufReader::new(stream);
        let mut responses = Vec::new();
        
        loop {
            let mut line = String::new();
            let bytes_read = reader.read_line(&mut line)
                .map_err(ClientError::Io)?;
            if bytes_read == 0 {
                break; // Connection closed
            }

            // Parse response based on the line
            let response = self.parse_response_line_with_reader(&line, &mut reader)?;
            
            // Check if this is a terminal response (single-line response that ends the command)
            let is_terminal = matches!(response, 
                FlareResponse::End | 
                FlareResponse::Ok |
                FlareResponse::Memcached(MemcachedResponse::Stored) |
                FlareResponse::Memcached(MemcachedResponse::NotStored) |
                FlareResponse::Memcached(MemcachedResponse::Exists) |
                FlareResponse::Memcached(MemcachedResponse::NotFound) |
                FlareResponse::Memcached(MemcachedResponse::Deleted) |
                FlareResponse::Memcached(MemcachedResponse::Touched) |
                FlareResponse::Memcached(MemcachedResponse::Error(_)) |
                FlareResponse::Memcached(MemcachedResponse::ClientError(_)) |
                FlareResponse::Memcached(MemcachedResponse::ServerError(_)) |
                FlareResponse::Memcached(MemcachedResponse::IncrDecr(_)) |
                FlareResponse::Memcached(MemcachedResponse::Version(_))
            );
            
            responses.push(response);
            
            if is_terminal {
                break;
            }
        }

        Ok(responses)
    }

    fn parse_response_line_with_reader(&self, line: &str, reader: &mut BufReader<&TcpStream>) -> Result<FlareResponse, ClientError> {
        let line = line.trim();
        let parts: Vec<&str> = line.split_whitespace().collect();
        
        if parts.is_empty() {
            return Err(ClientError::InvalidResponse("Empty response".to_string()));
        }

        match parts[0] {
            "OK" => Ok(FlareResponse::Ok),
            "END" => Ok(FlareResponse::End),
            "STORED" => Ok(FlareResponse::Memcached(MemcachedResponse::Stored)),
            "NOT_STORED" => Ok(FlareResponse::Memcached(MemcachedResponse::NotStored)),
            "EXISTS" => Ok(FlareResponse::Memcached(MemcachedResponse::Exists)),
            "NOT_FOUND" => Ok(FlareResponse::Memcached(MemcachedResponse::NotFound)),
            "DELETED" => Ok(FlareResponse::Memcached(MemcachedResponse::Deleted)),
            "TOUCHED" => Ok(FlareResponse::Memcached(MemcachedResponse::Touched)),
            "ERROR" => {
                let msg = if parts.len() > 1 { parts[1..].join(" ") } else { "Unknown error".to_string() };
                Ok(FlareResponse::Memcached(MemcachedResponse::Error(msg)))
            }
            "CLIENT_ERROR" => {
                let msg = if parts.len() > 1 { parts[1..].join(" ") } else { "Unknown client error".to_string() };
                Ok(FlareResponse::Memcached(MemcachedResponse::ClientError(msg)))
            }
            "SERVER_ERROR" => {
                let msg = if parts.len() > 1 { parts[1..].join(" ") } else { "Unknown server error".to_string() };
                Ok(FlareResponse::Memcached(MemcachedResponse::ServerError(msg)))
            }
            "VERSION" => {
                let version = if parts.len() > 1 { parts[1..].join(" ") } else { "Unknown".to_string() };
                Ok(FlareResponse::Memcached(MemcachedResponse::Version(version)))
            }
            "KEY" => {
                if parts.len() < 2 {
                    return Err(ClientError::InvalidResponse("Invalid KEY response".to_string()));
                }
                Ok(FlareResponse::Key { key: parts[1].to_string() })
            }
            "STAT" => {
                if parts.len() < 3 {
                    return Err(ClientError::InvalidResponse("Invalid STAT response".to_string()));
                }
                Ok(FlareResponse::Memcached(MemcachedResponse::Stat {
                    name: parts[1].to_string(),
                    value: parts[2].to_string(),
                }))
            }
            "VALUE" => {
                if parts.len() < 4 {
                    return Err(ClientError::InvalidResponse("Invalid VALUE response".to_string()));
                }
                let key = parts[1].to_string();
                let flags = parts[2].parse::<u32>()
                    .map_err(|_| ClientError::InvalidResponse("Invalid flags".to_string()))?;
                let bytes = parts[3].parse::<usize>()
                    .map_err(|_| ClientError::InvalidResponse("Invalid bytes".to_string()))?;
                
                // Parse optional fields based on number of parts
                let (cas_unique, exptime) = match parts.len() {
                    4 => (None, None), // get: VALUE key flags bytes
                    5 => {
                        // gets: VALUE key flags bytes version
                        // or dump with only version: VALUE key flags bytes version
                        let cas = parts[4].parse::<u64>()
                            .map_err(|_| ClientError::InvalidResponse("Invalid CAS".to_string()))?;
                        (Some(cas), None)
                    }
                    6 => {
                        // dump: VALUE key flags bytes version exptime
                        let cas = parts[4].parse::<u64>()
                            .map_err(|_| ClientError::InvalidResponse("Invalid CAS".to_string()))?;
                        let exp = parts[5].parse::<u32>()
                            .map_err(|_| ClientError::InvalidResponse("Invalid exptime".to_string()))?;
                        (Some(cas), Some(exp))
                    }
                    _ => return Err(ClientError::InvalidResponse("Invalid VALUE response format".to_string())),
                };
                
                // Read the data from the next line
                let mut data_line = String::new();
                reader.read_line(&mut data_line)
                    .map_err(ClientError::Io)?;
                
                // Remove trailing \r\n from data
                let data_str = data_line.trim_end();
                let data = bytes::Bytes::from(data_str.as_bytes().to_vec());
                
                Ok(FlareResponse::Memcached(MemcachedResponse::Value {
                    key,
                    flags,
                    bytes,
                    cas_unique,
                    exptime,
                    data,
                }))
            }
            _ => {
                // Try to parse as numeric response (for incr/decr)
                if let Ok(value) = line.parse::<u64>() {
                    Ok(FlareResponse::Memcached(MemcachedResponse::IncrDecr(value)))
                } else {
                    Err(ClientError::InvalidResponse(format!("Unknown response: {}", line)))
                }
            }
        }
    }

    #[allow(dead_code)]
    fn parse_response_line(&self, line: &str) -> Result<FlareResponse, ClientError> {
        let line = line.trim();
        let parts: Vec<&str> = line.split_whitespace().collect();
        
        if parts.is_empty() {
            return Err(ClientError::InvalidResponse("Empty response".to_string()));
        }

        match parts[0] {
            "OK" => Ok(FlareResponse::Ok),
            "END" => Ok(FlareResponse::End),
            "KEY" => {
                if parts.len() < 2 {
                    return Err(ClientError::InvalidResponse("Invalid KEY response".to_string()));
                }
                Ok(FlareResponse::Key { key: parts[1].to_string() })
            }
            "STAT" => {
                if parts.len() < 3 {
                    return Err(ClientError::InvalidResponse("Invalid STAT response".to_string()));
                }
                Ok(FlareResponse::Memcached(MemcachedResponse::Stat {
                    name: parts[1].to_string(),
                    value: parts[2..].join(" "),
                }))
            }
            "VALUE" => {
                if parts.len() < 4 {
                    return Err(ClientError::InvalidResponse("Invalid VALUE response".to_string()));
                }
                let key = parts[1].to_string();
                let flags = parts[2].parse::<u32>()
                    .map_err(|_| ClientError::InvalidResponse("Invalid flags".to_string()))?;
                let bytes = parts[3].parse::<usize>()
                    .map_err(|_| ClientError::InvalidResponse("Invalid bytes".to_string()))?;
                let cas_unique = if parts.len() > 4 {
                    Some(parts[4].parse::<u64>()
                        .map_err(|_| ClientError::InvalidResponse("Invalid CAS".to_string()))?)
                } else {
                    None
                };
                
                // Read the data (this is simplified - in real implementation we'd need to read exactly 'bytes' amount)
                let data = bytes::Bytes::new(); // Placeholder
                
                Ok(FlareResponse::Memcached(MemcachedResponse::Value {
                    key,
                    flags,
                    bytes,
                    cas_unique,
                    exptime: None,
                    data,
                }))
            }
            "STORED" => Ok(FlareResponse::Memcached(MemcachedResponse::Stored)),
            "NOT_STORED" => Ok(FlareResponse::Memcached(MemcachedResponse::NotStored)),
            "EXISTS" => Ok(FlareResponse::Memcached(MemcachedResponse::Exists)),
            "NOT_FOUND" => Ok(FlareResponse::Memcached(MemcachedResponse::NotFound)),
            "DELETED" => Ok(FlareResponse::Memcached(MemcachedResponse::Deleted)),
            "ERROR" => {
                let msg = if parts.len() > 1 { parts[1..].join(" ") } else { "Unknown error".to_string() };
                Ok(FlareResponse::Memcached(MemcachedResponse::Error(msg)))
            }
            "SERVER_ERROR" => {
                let msg = if parts.len() > 1 { parts[1..].join(" ") } else { "Unknown server error".to_string() };
                Ok(FlareResponse::Memcached(MemcachedResponse::ServerError(msg)))
            }
            "VERSION" => {
                let version = if parts.len() > 1 { parts[1..].join(" ") } else { "Unknown".to_string() };
                Ok(FlareResponse::Memcached(MemcachedResponse::Version(version)))
            }
            _ => {
                // Try to parse as numeric response (for incr/decr)
                if let Ok(value) = line.parse::<u64>() {
                    Ok(FlareResponse::Memcached(MemcachedResponse::IncrDecr(value)))
                } else {
                    Err(ClientError::InvalidResponse(format!("Unknown response: {}", line)))
                }
            }
        }
    }

    // High-level API methods
    pub fn ping(&mut self) -> Result<(), ClientError> {
        let responses = self.send_command(&FlareCommand::Ping)?;
        match responses.first() {
            Some(FlareResponse::Ok) => Ok(()),
            _ => Err(ClientError::InvalidResponse("Expected OK response".to_string())),
        }
    }

    pub fn get_stats(&mut self) -> Result<ClusterInfo, ClientError> {
        let stats_cmd = FlareCommand::Memcached(MemcachedCommand::Stats { args: Some("nodes".to_string()) });
        let responses = self.send_command(&stats_cmd)?;
        
        let mut nodes = Vec::new();
        let mut current_node = None;
        let mut node_host = String::new();
        let mut node_port = 0u16;
        let mut node_role = String::new();
        let mut node_state = String::new();
        let mut node_partition = 0i32;
        let mut node_balance = 0i32;

        for response in responses {
            if let FlareResponse::Memcached(MemcachedResponse::Stat { name, value }) = response {
                // Format: flared1:12121:role
                let parts: Vec<&str> = name.split(':').collect();
                if parts.len() >= 3 {
                    let host = parts[0].to_string();
                    let port = parts[1].parse::<u16>().unwrap_or(0);
                    let stat_name = parts[2];
                    
                    // If this is a new node, save the previous one
                    if current_node.is_none() || node_host != host || node_port != port {
                        if current_node.is_some() {
                            nodes.push(NodeInfo {
                                host: node_host.clone(),
                                port: node_port,
                                role: node_role.clone(),
                                state: node_state.clone(),
                                partition: node_partition,
                                balance: node_balance,
                                items: 0,
                                conn: 0,
                                behind: 0,
                                hit: 0.0,
                                size: 0,
                                uptime: String::new(),
                                version: String::new(),
                                qps: 0.0,
                                qpsr: 0.0,
                                qpsw: 0.0,
                            });
                        }
                        node_host = host;
                        node_port = port;
                        current_node = Some(());
                        // Reset node data
                        node_role = String::new();
                        node_state = String::new();
                        node_partition = -1;
                        node_balance = 0;
                    }
                    
                    // Update node info based on stat
                    match stat_name {
                        "role" => node_role = value,
                        "state" => node_state = value,
                        "partition" => node_partition = value.parse().unwrap_or(-1),
                        "balance" => node_balance = value.parse().unwrap_or(0),
                        _ => {}
                    }
                }
            }
        }

        // Add the last node
        if current_node.is_some() {
            nodes.push(NodeInfo {
                host: node_host,
                port: node_port,
                role: node_role,
                state: node_state,
                partition: node_partition,
                balance: node_balance,
                items: 0,
                conn: 0,
                behind: 0,
                hit: 0.0,
                size: 0,
                uptime: String::new(),
                version: String::new(),
                qps: 0.0,
                qpsr: 0.0,
                qpsw: 0.0,
            });
        }

        // Now query each node for detailed stats
        for node in &mut nodes {
            if let Ok(detailed_stats) = self.get_node_detailed_stats(&node.host, node.port) {
                node.items = detailed_stats.items;
                node.conn = detailed_stats.conn;
                node.behind = detailed_stats.behind;
                node.hit = detailed_stats.hit;
                node.size = detailed_stats.size;
                node.uptime = detailed_stats.uptime;
                node.version = detailed_stats.version;
                node.qps = detailed_stats.qps;
                node.qpsr = detailed_stats.qpsr;
                node.qpsw = detailed_stats.qpsw;
            }
        }

        Ok(ClusterInfo { nodes })
    }

    fn get_node_detailed_stats(&mut self, host: &str, port: u16) -> Result<NodeInfo, ClientError> {
        // Create a temporary client for this specific node
        let mut node_client = FlareClient::new(host.to_string(), port);
        
        // Query memcached stats from the individual node
        let stats_cmd = FlareCommand::Memcached(MemcachedCommand::Stats { args: None });
        let responses = node_client.send_command(&stats_cmd)?;
        
        let mut items = 0u64;
        let mut conn = 0u32;
        let mut behind = 0u64;
        let mut hit = 0.0f64;
        let mut size = 0u64;
        let mut uptime = String::new();
        let mut version = String::new();
        let mut qps = 0.0f64;
        let mut qpsr = 0.0f64;
        let mut qpsw = 0.0f64;
        
        for response in responses {
            if let FlareResponse::Memcached(MemcachedResponse::Stat { name, value }) = response {
                match name.as_str() {
                    "curr_items" => items = value.parse().unwrap_or(0),
                    "curr_connections" => conn = value.parse().unwrap_or(0),
                    "bytes" => size = value.parse().unwrap_or(0),
                    "uptime" => uptime = value,
                    "version" => version = value,
                    "get_hits" => {
                        if let Ok(hits) = value.parse::<u64>() {
                            let total_gets = hits + value.parse::<u64>().unwrap_or(0);
                            if total_gets > 0 {
                                hit = (hits as f64 / total_gets as f64) * 100.0;
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        
        // Calculate hit ratio properly by getting both hits and misses
        let mut get_hits = 0u64;
        let mut get_misses = 0u64;
        
        let stats_cmd2 = FlareCommand::Memcached(MemcachedCommand::Stats { args: None });
        let responses2 = node_client.send_command(&stats_cmd2)?;
        
        for response in responses2 {
            if let FlareResponse::Memcached(MemcachedResponse::Stat { name, value }) = response {
                match name.as_str() {
                    "get_hits" => get_hits = value.parse().unwrap_or(0),
                    "get_misses" => get_misses = value.parse().unwrap_or(0),
                    _ => {}
                }
            }
        }
        
        let total_gets = get_hits + get_misses;
        if total_gets > 0 {
            hit = (get_hits as f64 / total_gets as f64) * 100.0;
        }
        
        Ok(NodeInfo {
            host: host.to_string(),
            port,
            role: String::new(), // Will be filled by caller
            state: String::new(), // Will be filled by caller
            partition: -1, // Will be filled by caller
            balance: 0, // Will be filled by caller
            items,
            conn,
            behind,
            hit,
            size,
            uptime,
            version,
            qps,
            qpsr,
            qpsw,
        })
    }

    pub fn dump_keys(&mut self, partition: Option<u32>, partition_size: Option<u32>) -> Result<Vec<String>, ClientError> {
        let cmd = FlareCommand::DumpKey { partition, partition_size };
        let responses = self.send_command(&cmd)?;
        
        let mut keys = Vec::new();
        for response in responses {
            if let FlareResponse::Key { key } = response {
                keys.push(key);
            }
        }
        
        Ok(keys)
    }

    pub fn dump_data(&mut self, wait: Option<u64>, partition: Option<u32>, partition_size: Option<u32>, bwlimit: Option<u64>) -> Result<Vec<(String, bytes::Bytes)>, ClientError> {
        let cmd = FlareCommand::Memcached(MemcachedCommand::Dump { 
            wait, partition, partition_size, bwlimit 
        });
        let responses = self.send_command(&cmd)?;
        
        let mut data = Vec::new();
        for response in responses {
            if let FlareResponse::Memcached(MemcachedResponse::Value { key, data: value, .. }) = response {
                data.push((key, value));
            }
        }
        
        Ok(data)
    }

    pub fn dump_data_full(&mut self, wait: Option<u64>, partition: Option<u32>, partition_size: Option<u32>, bwlimit: Option<u64>) -> Result<Vec<MemcachedResponse>, ClientError> {
        let cmd = FlareCommand::Memcached(MemcachedCommand::Dump { 
            wait, partition, partition_size, bwlimit 
        });
        let responses = self.send_command(&cmd)?;
        
        let mut data = Vec::new();
        for response in responses {
            if let FlareResponse::Memcached(memcached_response) = response {
                match &memcached_response {
                    MemcachedResponse::Value { .. } => data.push(memcached_response),
                    MemcachedResponse::End => break,
                    _ => {} // Ignore other responses
                }
            }
        }
        
        Ok(data)
    }

    pub fn set_node_role(&mut self, host: String, port: u16, role: crate::protocol::NodeRole, balance: i32, partition: Option<i32>) -> Result<(), ClientError> {
        let cmd = FlareCommand::NodeRole { host, port, role, balance, partition };
        let responses = self.send_command(&cmd)?;
        
        match responses.first() {
            Some(FlareResponse::Ok) => Ok(()),
            _ => Err(ClientError::InvalidResponse("Expected OK response".to_string())),
        }
    }

    pub fn set_node_state(&mut self, host: String, port: u16, state: crate::protocol::NodeState) -> Result<(), ClientError> {
        let cmd = FlareCommand::NodeState { host, port, state };
        let responses = self.send_command(&cmd)?;
        
        match responses.first() {
            Some(FlareResponse::Ok) => Ok(()),
            _ => Err(ClientError::InvalidResponse("Expected OK response".to_string())),
        }
    }

    pub fn remove_node(&mut self, host: String, port: u16) -> Result<(), ClientError> {
        let cmd = FlareCommand::NodeRemove { host, port };
        let responses = self.send_command(&cmd)?;
        
        match responses.first() {
            Some(FlareResponse::Ok) => Ok(()),
            _ => Err(ClientError::InvalidResponse("Expected OK response".to_string())),
        }
    }

    pub fn flush_all(&mut self) -> Result<(), ClientError> {
        let cmd = FlareCommand::Memcached(MemcachedCommand::FlushAll { delay: None, noreply: false });
        let responses = self.send_command(&cmd)?;
        
        match responses.first() {
            Some(FlareResponse::Ok) => Ok(()),
            _ => Err(ClientError::InvalidResponse("Expected OK response".to_string())),
        }
    }

    pub fn get_thread_status(&mut self) -> Result<Vec<String>, ClientError> {
        let cmd = FlareCommand::Memcached(MemcachedCommand::Stats { args: Some("threads".to_string()) });
        let responses = self.send_command(&cmd)?;
        
        let mut stats = Vec::new();
        for response in responses {
            if let FlareResponse::Memcached(MemcachedResponse::Stat { name, value }) = response {
                stats.push(format!("STAT {} {}", name, value));
            }
        }
        
        Ok(stats)
    }

    pub fn get_version(&mut self) -> Result<String, ClientError> {
        let cmd = FlareCommand::Memcached(MemcachedCommand::Version);
        let responses = self.send_command(&cmd)?;
        
        match responses.first() {
            Some(FlareResponse::Memcached(MemcachedResponse::Version(v))) => Ok(v.clone()),
            _ => Err(ClientError::InvalidResponse("Expected VERSION response".to_string())),
        }
    }

    pub fn set_key_value(&mut self, key: &str, flags: u32, exptime: u32, data: &[u8]) -> Result<(), ClientError> {
        let cmd = FlareCommand::Memcached(MemcachedCommand::Set {
            key: key.to_string(),
            flags,
            exptime,
            bytes: data.len(),
            version: None,
            noreply: false,
            value: bytes::Bytes::copy_from_slice(data),
        });
        let responses = self.send_command(&cmd)?;
        
        match responses.first() {
            Some(FlareResponse::Memcached(MemcachedResponse::Stored)) => Ok(()),
            _ => Err(ClientError::InvalidResponse("Expected STORED response".to_string())),
        }
    }

    pub fn get_key_value(&mut self, key: &str) -> Result<Option<bytes::Bytes>, ClientError> {
        let cmd = FlareCommand::Memcached(MemcachedCommand::Get {
            keys: vec![key.to_string()],
        });
        let responses = self.send_command(&cmd)?;
        
        for response in responses {
            if let FlareResponse::Memcached(MemcachedResponse::Value { key: resp_key, data, .. }) = response {
                if resp_key == key {
                    return Ok(Some(data));
                }
            }
        }
        
        Ok(None)
    }

    pub fn generate_index_xml(&mut self) -> Result<String, ClientError> {
        let cluster_info = self.get_stats()?;
        
        let mut xml = String::new();
        xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\" ?>\n");
        xml.push_str("<!DOCTYPE boost_serialization>\n");
        xml.push_str("<boost_serialization signature=\"serialization::archive\" version=\"4\">\n");
        xml.push_str("<node_map class_id='0' tracking_level='0' version='0'>\n");

        for (i, node) in cluster_info.nodes.iter().enumerate() {
            xml.push_str(&format!(
                "  <item class_id='1' tracking_level='0' version='0'>\n\
                 <first>{}</first>\n\
                 <second class_id='2' tracking_level='1' version='0' object_id='_{}'>\n\
                 <node_server_name>{}</node_server_name>\n\
                 <node_server_port>{}</node_server_port>\n\
                 <node_role>{}</node_role>\n\
                 <node_state>{}</node_state>\n\
                 <node_partition>{}</node_partition>\n\
                 <node_balance>{}</node_balance>\n\
                 </second>\n\
                 </item>\n",
                node.partition, i, node.host, node.port, node.role, node.state, node.partition, node.balance
            ));
        }

        xml.push_str("</node_map>\n");
        xml.push_str("</boost_serialization>");

        Ok(xml)
    }
}

impl Drop for FlareClient {
    fn drop(&mut self) {
        let _ = self.disconnect();
    }
}
