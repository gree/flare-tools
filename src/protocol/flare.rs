use bytes::Bytes;
use std::str;
use thiserror::Error;

use super::memcached::{MemcachedCommand, MemcachedError, MemcachedParser, MemcachedResponse};

#[derive(Debug, Error)]
pub enum FlareError {
    #[error("Memcached error: {0}")]
    MemcachedError(#[from] MemcachedError),
    #[error("Invalid node command")]
    InvalidNodeCommand,
    #[error("Parse error: {0}")]
    ParseError(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum FlareCommand {
    // Standard memcached commands
    Memcached(MemcachedCommand),
    
    // Flare-specific commands
    DumpKey {
        partition: Option<u32>,
        partition_size: Option<u32>,
    },
    NodeAdd {
        host: String,
        port: u16,
    },
    NodeRole {
        host: String,
        port: u16,
        role: NodeRole,
        balance: i32,
        partition: Option<i32>,
    },
    NodeState {
        host: String,
        port: u16,
        state: NodeState,
    },
    NodeRemove {
        host: String,
        port: u16,
    },
    NodeSync,
    Ping,
    Kill {
        thread_id: u32,
    },
}

#[derive(Debug, Clone, PartialEq)]
pub enum NodeRole {
    Master,
    Slave,
    Proxy,
}

#[derive(Debug, Clone, PartialEq)]
pub enum NodeState {
    Active,
    Prepare,
    Down,
}

#[derive(Debug, Clone, PartialEq)]
pub enum FlareResponse {
    // Standard memcached responses
    Memcached(MemcachedResponse),
    
    // Flare-specific responses
    Key {
        key: String,
    },
    Node {
        host: String,
        port: u16,
        role: String,
        state: String,
        partition: i32,
        balance: i32,
        thread_type: String,
    },
    Ok,
    End,
}

pub struct FlareParser {
    memcached_parser: MemcachedParser,
}

impl FlareParser {
    pub fn new() -> Self {
        FlareParser {
            memcached_parser: MemcachedParser::new(),
        }
    }

    pub fn parse_command(&self, input: &[u8]) -> Result<(FlareCommand, usize), FlareError> {
        // Try to parse as a flare-specific command first
        let command_end = self.find_command_end(input)?;
        let command_line = &input[0..command_end];
        let input_str = str::from_utf8(command_line)
            .map_err(|e| FlareError::ParseError(e.to_string()))?;
        
        let parts: Vec<&str> = input_str.split_whitespace().collect();
        if parts.is_empty() {
            return Err(FlareError::ParseError("Empty command".to_string()));
        }

        match parts[0] {
            "dump_key" => self.parse_dump_key_command(parts),
            "node" => self.parse_node_command(parts),
            "ping" => Ok((FlareCommand::Ping, parts.join(" ").len() + 2)),
            "kill" => self.parse_kill_command(parts),
            _ => {
                // Fall back to memcached parser
                match self.memcached_parser.parse_command(input) {
                    Ok((cmd, consumed)) => Ok((FlareCommand::Memcached(cmd), consumed)),
                    Err(e) => Err(FlareError::MemcachedError(e)),
                }
            }
        }
    }

    fn find_command_end(&self, input: &[u8]) -> Result<usize, FlareError> {
        for i in 0..input.len().saturating_sub(1) {
            if input[i] == b'\r' && input[i + 1] == b'\n' {
                return Ok(i);
            }
        }
        Err(FlareError::ParseError("No command terminator found".to_string()))
    }

    fn parse_dump_key_command(&self, parts: Vec<&str>) -> Result<(FlareCommand, usize), FlareError> {
        let (partition, partition_size) = if parts.len() > 2 {
            let p = parts[1].parse::<u32>()
                .map_err(|_| FlareError::ParseError("Invalid partition".to_string()))?;
            let ps = parts[2].parse::<u32>()
                .map_err(|_| FlareError::ParseError("Invalid partition_size".to_string()))?;
            
            if p >= ps {
                return Err(FlareError::ParseError(
                    "partition must be less than partition_size".to_string()
                ));
            }
            
            (Some(p), Some(ps))
        } else {
            (None, None)
        };

        let total_len = parts.join(" ").len() + 2;
        Ok((FlareCommand::DumpKey { partition, partition_size }, total_len))
    }

    fn parse_node_command(&self, parts: Vec<&str>) -> Result<(FlareCommand, usize), FlareError> {
        if parts.len() < 2 {
            return Err(FlareError::InvalidNodeCommand);
        }

        let subcommand = parts[1];
        let total_len = parts.join(" ").len() + 2;

        match subcommand {
            "add" => {
                if parts.len() != 4 {
                    return Err(FlareError::ParseError("node add requires host and port".to_string()));
                }
                let host = parts[2].to_string();
                let port = parts[3].parse::<u16>()
                    .map_err(|_| FlareError::ParseError("Invalid port".to_string()))?;
                Ok((FlareCommand::NodeAdd { host, port }, total_len))
            }
            "role" => {
                if parts.len() < 6 {
                    return Err(FlareError::ParseError("node role requires host:port role balance [partition]".to_string()));
                }
                let (host, port) = self.parse_host_port(parts[2])?;
                let role = match parts[3] {
                    "master" => NodeRole::Master,
                    "slave" => NodeRole::Slave,
                    "proxy" => NodeRole::Proxy,
                    _ => return Err(FlareError::ParseError("Invalid role".to_string())),
                };
                let balance = parts[4].parse::<i32>()
                    .map_err(|_| FlareError::ParseError("Invalid balance".to_string()))?;
                let partition = if parts.len() > 5 {
                    Some(parts[5].parse::<i32>()
                        .map_err(|_| FlareError::ParseError("Invalid partition".to_string()))?)
                } else {
                    None
                };
                Ok((FlareCommand::NodeRole { host, port, role, balance, partition }, total_len))
            }
            "state" => {
                if parts.len() != 4 {
                    return Err(FlareError::ParseError("node state requires host:port state".to_string()));
                }
                let (host, port) = self.parse_host_port(parts[2])?;
                let state = match parts[3] {
                    "active" => NodeState::Active,
                    "prepare" => NodeState::Prepare,
                    "down" => NodeState::Down,
                    _ => return Err(FlareError::ParseError("Invalid state".to_string())),
                };
                Ok((FlareCommand::NodeState { host, port, state }, total_len))
            }
            "remove" => {
                if parts.len() != 3 {
                    return Err(FlareError::ParseError("node remove requires host:port".to_string()));
                }
                let (host, port) = self.parse_host_port(parts[2])?;
                Ok((FlareCommand::NodeRemove { host, port }, total_len))
            }
            "sync" => {
                Ok((FlareCommand::NodeSync, total_len))
            }
            _ => Err(FlareError::ParseError("Invalid node subcommand".to_string())),
        }
    }

    fn parse_kill_command(&self, parts: Vec<&str>) -> Result<(FlareCommand, usize), FlareError> {
        if parts.len() != 2 {
            return Err(FlareError::ParseError("kill requires thread_id".to_string()));
        }
        
        let thread_id = parts[1].parse::<u32>()
            .map_err(|_| FlareError::ParseError("Invalid thread_id".to_string()))?;
        
        let total_len = parts.join(" ").len() + 2;
        Ok((FlareCommand::Kill { thread_id }, total_len))
    }

    fn parse_host_port(&self, s: &str) -> Result<(String, u16), FlareError> {
        let parts: Vec<&str> = s.split(':').collect();
        if parts.len() != 2 {
            return Err(FlareError::ParseError("Invalid host:port format".to_string()));
        }
        
        let host = parts[0].to_string();
        let port = parts[1].parse::<u16>()
            .map_err(|_| FlareError::ParseError("Invalid port".to_string()))?;
        
        Ok((host, port))
    }

    pub fn format_response(&self, response: &FlareResponse) -> Bytes {
        match response {
            FlareResponse::Memcached(mc_response) => self.memcached_parser.format_response(mc_response),
            FlareResponse::Key { key } => Bytes::from(format!("KEY {}\r\n", key)),
            FlareResponse::Node { host, port, role, state, partition, balance, thread_type } => {
                Bytes::from(format!("NODE {} {} {} {} {} {} {}\r\n", 
                    host, port, role, state, partition, balance, thread_type))
            }
            FlareResponse::Ok => Bytes::from("OK\r\n"),
            FlareResponse::End => Bytes::from("END\r\n"),
        }
    }

    pub fn format_command(command: &FlareCommand) -> Bytes {
        match command {
            FlareCommand::Memcached(mc_cmd) => MemcachedParser::format_command(mc_cmd),
            FlareCommand::DumpKey { partition, partition_size } => {
                let cmd = match (partition, partition_size) {
                    (Some(p), Some(ps)) => format!("dump_key {} {}\r\n", p, ps),
                    _ => "dump_key\r\n".to_string(),
                };
                Bytes::from(cmd)
            }
            FlareCommand::NodeAdd { host, port } => {
                Bytes::from(format!("node add {} {}\r\n", host, port))
            }
            FlareCommand::NodeRole { host, port, role, balance, partition } => {
                let role_str = match role {
                    NodeRole::Master => "master",
                    NodeRole::Slave => "slave", 
                    NodeRole::Proxy => "proxy",
                };
                let cmd = if let Some(p) = partition {
                    format!("node role {} {} {} {} {}\r\n", host, port, role_str, balance, p)
                } else {
                    format!("node role {} {} {} {}\r\n", host, port, role_str, balance)
                };
                Bytes::from(cmd)
            }
            FlareCommand::NodeState { host, port, state } => {
                let state_str = match state {
                    NodeState::Active => "active",
                    NodeState::Prepare => "prepare",
                    NodeState::Down => "down",
                };
                Bytes::from(format!("node state {} {} {}\r\n", host, port, state_str))
            }
            FlareCommand::NodeRemove { host, port } => {
                Bytes::from(format!("node remove {} {}\r\n", host, port))
            }
            FlareCommand::NodeSync => Bytes::from("node sync\r\n"),
            FlareCommand::Ping => Bytes::from("ping\r\n"),
            FlareCommand::Kill { thread_id } => {
                Bytes::from(format!("kill {}\r\n", thread_id))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_dump_key_command() {
        let parser = FlareParser::new();
        
        // Test without partition
        let input = b"dump_key\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        match cmd {
            FlareCommand::DumpKey { partition, partition_size } => {
                assert_eq!(partition, None);
                assert_eq!(partition_size, None);
            }
            _ => panic!("Expected DumpKey command"),
        }
        assert_eq!(consumed, input.len());

        // Test with partition
        let input = b"dump_key 0 5\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        match cmd {
            FlareCommand::DumpKey { partition, partition_size } => {
                assert_eq!(partition, Some(0));
                assert_eq!(partition_size, Some(5));
            }
            _ => panic!("Expected DumpKey command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_node_role_command() {
        let parser = FlareParser::new();
        let input = b"node role localhost:12121 master 1 0\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        
        match cmd {
            FlareCommand::NodeRole { host, port, role, balance, partition } => {
                assert_eq!(host, "localhost");
                assert_eq!(port, 12121);
                assert_eq!(role, NodeRole::Master);
                assert_eq!(balance, 1);
                assert_eq!(partition, Some(0));
            }
            _ => panic!("Expected NodeRole command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_node_state_command() {
        let parser = FlareParser::new();
        let input = b"node state localhost:12121 down\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        
        match cmd {
            FlareCommand::NodeState { host, port, state } => {
                assert_eq!(host, "localhost");
                assert_eq!(port, 12121);
                assert_eq!(state, NodeState::Down);
            }
            _ => panic!("Expected NodeState command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_format_key_response() {
        let parser = FlareParser::new();
        let response = FlareResponse::Key { key: "test_key".to_string() };
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("KEY test_key\r\n"));
    }

    #[test]
    fn test_parse_ping_command() {
        let parser = FlareParser::new();
        let input = b"ping\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        
        match cmd {
            FlareCommand::Ping => {},
            _ => panic!("Expected Ping command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_kill_command() {
        let parser = FlareParser::new();
        let input = b"kill 42\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        
        match cmd {
            FlareCommand::Kill { thread_id } => {
                assert_eq!(thread_id, 42);
            }
            _ => panic!("Expected Kill command"),
        }
        assert_eq!(consumed, input.len());
    }
}