use bytes::{Bytes, BytesMut};
use std::str;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum MemcachedError {
    #[error("Invalid command format")]
    InvalidCommand,
    #[error("Invalid key")]
    #[allow(dead_code)]
    InvalidKey,
    #[error("Invalid value")]
    #[allow(dead_code)]
    InvalidValue,
    #[error("Protocol error: {0}")]
    #[allow(dead_code)]
    ProtocolError(String),
    #[error("Parse error: {0}")]
    ParseError(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum MemcachedCommand {
    Set {
        key: String,
        flags: u32,
        exptime: u32,
        bytes: usize,
        version: Option<u64>,
        noreply: bool,
        value: Bytes,
    },
    Add {
        key: String,
        flags: u32,
        exptime: u32,
        bytes: usize,
        noreply: bool,
        value: Bytes,
    },
    Replace {
        key: String,
        flags: u32,
        exptime: u32,
        bytes: usize,
        noreply: bool,
        value: Bytes,
    },
    Append {
        key: String,
        flags: u32,
        exptime: u32,
        bytes: usize,
        noreply: bool,
        value: Bytes,
    },
    Prepend {
        key: String,
        flags: u32,
        exptime: u32,
        bytes: usize,
        noreply: bool,
        value: Bytes,
    },
    Cas {
        key: String,
        flags: u32,
        exptime: u32,
        bytes: usize,
        cas_unique: u64,
        noreply: bool,
        value: Bytes,
    },
    Get {
        keys: Vec<String>,
    },
    Gets {
        keys: Vec<String>,
    },
    Delete {
        key: String,
        noreply: bool,
    },
    Incr {
        key: String,
        value: u64,
        noreply: bool,
    },
    Decr {
        key: String,
        value: u64,
        noreply: bool,
    },
    Touch {
        key: String,
        exptime: u32,
        noreply: bool,
    },
    Stats {
        args: Option<String>,
    },
    FlushAll {
        delay: Option<u32>,
        noreply: bool,
    },
    Version,
    Quit,
    Gat {
        exptime: u32,
        keys: Vec<String>,
    },
    Gats {
        exptime: u32,
        keys: Vec<String>,
    },
    Verbosity {
        level: u32,
        noreply: bool,
    },
    CacheMemlimit {
        memlimit: u32,
        noreply: bool,
    },
    Dump {
        wait: Option<u64>,           // microseconds
        partition: Option<u32>,      // partition index
        partition_size: Option<u32>, // total partitions
        bwlimit: Option<u64>,        // bytes/sec
    },
}

#[derive(Debug, Clone, PartialEq)]
pub enum MemcachedResponse {
    Stored,
    NotStored,
    Exists,
    NotFound,
    Deleted,
    Touched,
    Ok,
    Error(String),
    #[allow(dead_code)]
    ClientError(String),
    ServerError(String),
    Value {
        key: String,
        flags: u32,
        bytes: usize,
        cas_unique: Option<u64>,
        exptime: Option<u32>,
        data: Bytes,
    },
    End,
    Version(String),
    Stat {
        name: String,
        value: String,
    },
    IncrDecr(u64),
}

pub struct MemcachedParser;

impl MemcachedParser {
    pub fn new() -> Self {
        MemcachedParser
    }

    pub fn parse_command(&self, input: &[u8]) -> Result<(MemcachedCommand, usize), MemcachedError> {
        // For commands with binary data, we need to handle parsing differently
        // First, find the first \r\n to get the command line
        let mut command_end = None;
        for i in 0..input.len().saturating_sub(1) {
            if input[i] == b'\r' && input[i + 1] == b'\n' {
                command_end = Some(i);
                break;
            }
        }

        let command_end = command_end.ok_or(MemcachedError::ParseError(
            "No command terminator found".to_string(),
        ))?;
        let command_line = &input[0..command_end];

        let input_str =
            str::from_utf8(command_line).map_err(|e| MemcachedError::ParseError(e.to_string()))?;

        let parts: Vec<&str> = input_str.split_whitespace().collect();
        if parts.is_empty() {
            return Err(MemcachedError::InvalidCommand);
        }

        match parts[0] {
            "set" => self.parse_storage_command(parts, input, false),
            "add" => self.parse_storage_command(parts, input, false),
            "replace" => self.parse_storage_command(parts, input, false),
            "append" => self.parse_storage_command(parts, input, false),
            "prepend" => self.parse_storage_command(parts, input, false),
            "cas" => self.parse_storage_command(parts, input, true),
            "get" => self.parse_retrieval_command(parts, false),
            "gets" => self.parse_retrieval_command(parts, true),
            "delete" => self.parse_delete_command(parts),
            "incr" => self.parse_incr_decr_command(parts, true),
            "decr" => self.parse_incr_decr_command(parts, false),
            "touch" => self.parse_touch_command(parts),
            "stats" => self.parse_stats_command(parts),
            "flush_all" => self.parse_flush_all_command(parts),
            "gat" => self.parse_gat_command(parts, false),
            "gats" => self.parse_gat_command(parts, true),
            "verbosity" => self.parse_verbosity_command(parts),
            "cache_memlimit" => self.parse_cache_memlimit_command(parts),
            "dump" => self.parse_dump_command(parts),
            "version" => Ok((MemcachedCommand::Version, parts[0].len() + 2)),
            "quit" => Ok((MemcachedCommand::Quit, parts[0].len() + 2)),
            _ => Err(MemcachedError::InvalidCommand),
        }
    }

    fn parse_storage_command(
        &self,
        parts: Vec<&str>,
        input: &[u8],
        is_cas: bool,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        let is_set = parts[0] == "set";
        
        // For SET: can be 5 (basic), 6 (with version or noreply), or 7 (with version and noreply)
        // For CAS: must be 6 (with cas_unique) or 7 (with cas_unique and noreply)
        // For others: 5 (basic) or 6 (with noreply)
        let min_parts = 5;
        let max_parts = if is_set || is_cas { 7 } else { 6 };

        if parts.len() < min_parts || parts.len() > max_parts {
            return Err(MemcachedError::InvalidCommand);
        }

        let key = parts[1].to_string();
        let flags = parts[2]
            .parse::<u32>()
            .map_err(|_| MemcachedError::ParseError("Invalid flags".to_string()))?;
        let exptime = parts[3]
            .parse::<u32>()
            .map_err(|_| MemcachedError::ParseError("Invalid exptime".to_string()))?;
        let bytes = if parts.len() > 4 {
            parts[4]
                .parse::<usize>()
                .map_err(|_| MemcachedError::ParseError("Invalid bytes".to_string()))?
        } else {
            return Err(MemcachedError::InvalidCommand);
        };

        // Parse version/cas_unique and determine noreply index
        let (version_or_cas, noreply_index) = if is_cas {
            // CAS requires version at position 5
            if parts.len() > 5 {
                let cas = parts[5]
                    .parse::<u64>()
                    .map_err(|_| MemcachedError::ParseError("Invalid CAS value".to_string()))?;
                (Some(cas), 6)
            } else {
                return Err(MemcachedError::InvalidCommand);
            }
        } else if is_set && parts.len() > 5 {
            // SET with optional version at position 5
            // Check if position 5 is a number (version) or "noreply"
            if parts[5] == "noreply" {
                (None, 5)
            } else {
                match parts[5].parse::<u64>() {
                    Ok(version) => (Some(version), 6),
                    Err(_) => return Err(MemcachedError::ParseError("Invalid version".to_string())),
                }
            }
        } else {
            (None, 5)
        };

        let noreply = parts
            .get(noreply_index)
            .map(|&s| s == "noreply")
            .unwrap_or(false);

        // Find the command line end (\r\n)
        let mut command_end = None;
        for i in 0..input.len().saturating_sub(1) {
            if input[i] == b'\r' && input[i + 1] == b'\n' {
                command_end = Some(i + 2); // Include \r\n
                break;
            }
        }

        let command_line_end = command_end.ok_or(MemcachedError::ParseError(
            "No command terminator found".to_string(),
        ))?;
        let total_len = command_line_end + bytes + 2; // command + data + \r\n
                                                      // Extract the value data - ensure we have the complete command including final \r\n
        if input.len() < total_len {
            return Err(MemcachedError::ParseError("Incomplete data".to_string()));
        }

        let value_start = command_line_end;
        let value_end = value_start + bytes;
        let value = Bytes::from(input[value_start..value_end].to_vec());

        let cmd = match parts[0] {
            "set" => MemcachedCommand::Set {
                key,
                flags,
                exptime,
                bytes,
                version: if is_set { version_or_cas } else { None },
                noreply,
                value,
            },
            "add" => MemcachedCommand::Add {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            },
            "replace" => MemcachedCommand::Replace {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            },
            "append" => MemcachedCommand::Append {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            },
            "prepend" => MemcachedCommand::Prepend {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            },
            "cas" => MemcachedCommand::Cas {
                key,
                flags,
                exptime,
                bytes,
                cas_unique: version_or_cas.unwrap(),
                noreply,
                value,
            },
            _ => unreachable!(),
        };

        Ok((cmd, total_len))
    }

    fn parse_retrieval_command(
        &self,
        parts: Vec<&str>,
        with_cas: bool,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() < 2 {
            return Err(MemcachedError::InvalidCommand);
        }

        let keys: Vec<String> = parts[1..].iter().map(|&s| s.to_string()).collect();
        let total_len = parts.join(" ").len() + 2; // +2 for \r\n

        let cmd = if with_cas {
            MemcachedCommand::Gets { keys }
        } else {
            MemcachedCommand::Get { keys }
        };

        Ok((cmd, total_len))
    }

    fn parse_delete_command(
        &self,
        parts: Vec<&str>,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() < 2 || parts.len() > 3 {
            return Err(MemcachedError::InvalidCommand);
        }

        let key = parts[1].to_string();
        let noreply = parts.get(2).map(|&s| s == "noreply").unwrap_or(false);
        let total_len = parts.join(" ").len() + 2;

        Ok((MemcachedCommand::Delete { key, noreply }, total_len))
    }

    fn parse_incr_decr_command(
        &self,
        parts: Vec<&str>,
        is_incr: bool,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() < 3 || parts.len() > 4 {
            return Err(MemcachedError::InvalidCommand);
        }

        let key = parts[1].to_string();
        let value = parts[2]
            .parse::<u64>()
            .map_err(|_| MemcachedError::ParseError("Invalid numeric value".to_string()))?;
        let noreply = parts.get(3).map(|&s| s == "noreply").unwrap_or(false);
        let total_len = parts.join(" ").len() + 2;

        let cmd = if is_incr {
            MemcachedCommand::Incr {
                key,
                value,
                noreply,
            }
        } else {
            MemcachedCommand::Decr {
                key,
                value,
                noreply,
            }
        };

        Ok((cmd, total_len))
    }

    fn parse_touch_command(
        &self,
        parts: Vec<&str>,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() < 3 || parts.len() > 4 {
            return Err(MemcachedError::InvalidCommand);
        }

        let key = parts[1].to_string();
        let exptime = parts[2]
            .parse::<u32>()
            .map_err(|_| MemcachedError::ParseError("Invalid exptime".to_string()))?;
        let noreply = parts.get(3).map(|&s| s == "noreply").unwrap_or(false);
        let total_len = parts.join(" ").len() + 2;

        Ok((
            MemcachedCommand::Touch {
                key,
                exptime,
                noreply,
            },
            total_len,
        ))
    }

    fn parse_stats_command(
        &self,
        parts: Vec<&str>,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        let args = if parts.len() > 1 {
            Some(parts[1..].join(" "))
        } else {
            None
        };
        let total_len = parts.join(" ").len() + 2;

        Ok((MemcachedCommand::Stats { args }, total_len))
    }

    fn parse_flush_all_command(
        &self,
        parts: Vec<&str>,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() > 3 {
            return Err(MemcachedError::InvalidCommand);
        }

        let mut delay = None;
        let mut noreply = false;

        if parts.len() >= 2 {
            if parts[1] == "noreply" {
                noreply = true;
            } else {
                delay = Some(
                    parts[1]
                        .parse::<u32>()
                        .map_err(|_| MemcachedError::ParseError("Invalid delay".to_string()))?,
                );
                if parts.len() == 3 && parts[2] == "noreply" {
                    noreply = true;
                }
            }
        }

        let total_len = parts.join(" ").len() + 2;
        Ok((MemcachedCommand::FlushAll { delay, noreply }, total_len))
    }

    fn parse_gat_command(
        &self,
        parts: Vec<&str>,
        with_cas: bool,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() < 3 {
            return Err(MemcachedError::InvalidCommand);
        }

        let exptime = parts[1]
            .parse::<u32>()
            .map_err(|_| MemcachedError::ParseError("Invalid exptime".to_string()))?;
        let keys: Vec<String> = parts[2..].iter().map(|&s| s.to_string()).collect();
        let total_len = parts.join(" ").len() + 2;

        let cmd = if with_cas {
            MemcachedCommand::Gats { exptime, keys }
        } else {
            MemcachedCommand::Gat { exptime, keys }
        };

        Ok((cmd, total_len))
    }

    fn parse_verbosity_command(
        &self,
        parts: Vec<&str>,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() < 2 || parts.len() > 3 {
            return Err(MemcachedError::InvalidCommand);
        }

        let level = parts[1]
            .parse::<u32>()
            .map_err(|_| MemcachedError::ParseError("Invalid verbosity level".to_string()))?;
        let noreply = parts.get(2).map(|&s| s == "noreply").unwrap_or(false);
        let total_len = parts.join(" ").len() + 2;

        Ok((MemcachedCommand::Verbosity { level, noreply }, total_len))
    }

    fn parse_cache_memlimit_command(
        &self,
        parts: Vec<&str>,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        if parts.len() < 2 || parts.len() > 3 {
            return Err(MemcachedError::InvalidCommand);
        }

        let memlimit = parts[1]
            .parse::<u32>()
            .map_err(|_| MemcachedError::ParseError("Invalid memory limit".to_string()))?;
        let noreply = parts.get(2).map(|&s| s == "noreply").unwrap_or(false);
        let total_len = parts.join(" ").len() + 2;

        Ok((
            MemcachedCommand::CacheMemlimit { memlimit, noreply },
            total_len,
        ))
    }

    fn parse_dump_command(
        &self,
        parts: Vec<&str>,
    ) -> Result<(MemcachedCommand, usize), MemcachedError> {
        // dump [<wait> [<partition> <partition_size> [<bwlimit>]]]
        if parts.len() > 5 {
            return Err(MemcachedError::InvalidCommand);
        }

        let wait = if parts.len() > 1 {
            Some(
                parts[1]
                    .parse::<u64>()
                    .map_err(|_| MemcachedError::ParseError("Invalid wait value".to_string()))?,
            )
        } else {
            None
        };

        let (partition, partition_size) = if parts.len() > 3 {
            let p = parts[2]
                .parse::<u32>()
                .map_err(|_| MemcachedError::ParseError("Invalid partition value".to_string()))?;
            let ps = parts[3].parse::<u32>().map_err(|_| {
                MemcachedError::ParseError("Invalid partition_size value".to_string())
            })?;

            // Validate partition < partition_size
            if p >= ps {
                return Err(MemcachedError::ParseError(
                    "partition must be less than partition_size".to_string(),
                ));
            }

            (Some(p), Some(ps))
        } else {
            (None, None)
        };

        let bwlimit = if parts.len() > 4 {
            Some(
                parts[4]
                    .parse::<u64>()
                    .map_err(|_| MemcachedError::ParseError("Invalid bwlimit value".to_string()))?,
            )
        } else {
            None
        };

        let total_len = parts.join(" ").len() + 2;

        Ok((
            MemcachedCommand::Dump {
                wait,
                partition,
                partition_size,
                bwlimit,
            },
            total_len,
        ))
    }

    pub fn format_response(&self, response: &MemcachedResponse) -> Bytes {
        match response {
            MemcachedResponse::Stored => Bytes::from("STORED\r\n"),
            MemcachedResponse::NotStored => Bytes::from("NOT_STORED\r\n"),
            MemcachedResponse::Exists => Bytes::from("EXISTS\r\n"),
            MemcachedResponse::NotFound => Bytes::from("NOT_FOUND\r\n"),
            MemcachedResponse::Deleted => Bytes::from("DELETED\r\n"),
            MemcachedResponse::Touched => Bytes::from("TOUCHED\r\n"),
            MemcachedResponse::Ok => Bytes::from("OK\r\n"),
            MemcachedResponse::Error(msg) => Bytes::from(format!("ERROR {}\r\n", msg)),
            MemcachedResponse::ClientError(msg) => Bytes::from(format!("CLIENT_ERROR {}\r\n", msg)),
            MemcachedResponse::ServerError(msg) => Bytes::from(format!("SERVER_ERROR {}\r\n", msg)),
            MemcachedResponse::Value {
                key,
                flags,
                bytes,
                cas_unique,
                exptime,
                data,
            } => {
                let response = match (cas_unique, exptime) {
                    (Some(cas), Some(exp)) => format!("VALUE {} {} {} {} {}\r\n", key, flags, bytes, cas, exp),
                    (Some(cas), None) => format!("VALUE {} {} {} {}\r\n", key, flags, bytes, cas),
                    (None, Some(exp)) => format!("VALUE {} {} {} {}\r\n", key, flags, bytes, exp),
                    (None, None) => format!("VALUE {} {} {}\r\n", key, flags, bytes),
                };
                let mut result = BytesMut::from(response.as_bytes());
                result.extend_from_slice(&data);
                result.extend_from_slice(b"\r\n");
                result.freeze()
            }
            MemcachedResponse::End => Bytes::from("END\r\n"),
            MemcachedResponse::Version(v) => Bytes::from(format!("VERSION {}\r\n", v)),
            MemcachedResponse::Stat { name, value } => {
                if name.is_empty() {
                    Bytes::from("END\r\n")
                } else {
                    Bytes::from(format!("STAT {} {}\r\n", name, value))
                }
            }
            MemcachedResponse::IncrDecr(value) => Bytes::from(format!("{}\r\n", value)),
        }
    }

    pub fn format_command(command: &MemcachedCommand) -> Bytes {
        match command {
            MemcachedCommand::Set {
                key,
                flags,
                exptime,
                bytes,
                version,
                noreply,
                value,
            } => {
                let mut command_str = format!(
                    "set {} {} {} {}",
                    key, flags, exptime, bytes
                );
                if let Some(v) = version {
                    command_str.push_str(&format!(" {}", v));
                }
                if *noreply {
                    command_str.push_str(" noreply");
                }
                command_str.push_str("\r\n");
                println!("set {}",command_str);

                println!("value {}", str::from_utf8(value).unwrap());
                let mut result = BytesMut::from(command_str.as_bytes());
                result.extend_from_slice(value);
                result.extend_from_slice(b"\r\n");
                result.freeze()
            }
            MemcachedCommand::Stats { args } => {
                if let Some(arg) = args {
                    Bytes::from(format!("stats {}\r\n", arg))
                } else {
                    Bytes::from("stats\r\n")
                }
            }
            MemcachedCommand::Get { keys } => {
                let keys_str = keys.join(" ");
                Bytes::from(format!("get {}\r\n", keys_str))
            }
            MemcachedCommand::FlushAll { delay, noreply } => {
                let mut cmd = "flush_all".to_string();
                if let Some(d) = delay {
                    cmd.push_str(&format!(" {}", d));
                }
                if *noreply {
                    cmd.push_str(" noreply");
                }
                cmd.push_str("\r\n");
                Bytes::from(cmd)
            }
            MemcachedCommand::Version => Bytes::from("version\r\n"),
            MemcachedCommand::Dump { wait, partition, partition_size, bwlimit } => {
                let mut cmd = "dump".to_string();
                if let Some(w) = wait {
                    cmd.push_str(&format!(" {}", w));
                }
                if let (Some(p), Some(ps)) = (partition, partition_size) {
                    cmd.push_str(&format!(" {} {}", p, ps));
                }
                if let Some(bw) = bwlimit {
                    cmd.push_str(&format!(" {}", bw));
                }
                cmd.push_str("\r\n");
                Bytes::from(cmd)
            }
            _ => unimplemented!("Command not implemented: {:?}", command),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_set_command() {
        let parser = MemcachedParser::new();
        let input = b"set mykey 0 3600 5\r\nhello\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Set {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
                ..
            } => {
                assert_eq!(key, "mykey");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 3600);
                assert_eq!(bytes, 5);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("hello"));
            }
            _ => panic!("Expected Set command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_get_command() {
        let parser = MemcachedParser::new();
        let input = b"get key1 key2 key3\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Get { keys } => {
                assert_eq!(keys, vec!["key1", "key2", "key3"]);
            }
            _ => panic!("Expected Get command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_cas_command() {
        let parser = MemcachedParser::new();
        let input = b"cas mykey 0 3600 5 12345\r\nhello\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Cas {
                key,
                flags,
                exptime,
                bytes,
                cas_unique,
                noreply,
                value,
            } => {
                assert_eq!(key, "mykey");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 3600);
                assert_eq!(bytes, 5);
                assert_eq!(cas_unique, 12345);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("hello"));
            }
            _ => panic!("Expected CAS command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_delete_command() {
        let parser = MemcachedParser::new();
        let input = b"delete mykey noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Delete { key, noreply } => {
                assert_eq!(key, "mykey");
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected Delete command"),
        }
    }

    #[test]
    fn test_format_response() {
        let parser = MemcachedParser::new();

        let response = MemcachedResponse::Stored;
        assert_eq!(parser.format_response(&response), Bytes::from("STORED\r\n"));

        let response = MemcachedResponse::Value {
            key: "mykey".to_string(),
            flags: 0,
            bytes: 5,
            cas_unique: None,
            data: Bytes::from("hello"),
        };
        let formatted = parser.format_response(&response);
        let expected = b"VALUE mykey 0 5\r\nhello\r\n";
        assert_eq!(formatted, Bytes::from(&expected[..]));
    }

    #[test]
    fn test_parse_dump_command() {
        let parser = MemcachedParser::new();

        // Test basic dump command
        let input = b"dump\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        match cmd {
            MemcachedCommand::Dump {
                wait,
                partition,
                partition_size,
                bwlimit,
            } => {
                assert_eq!(wait, None);
                assert_eq!(partition, None);
                assert_eq!(partition_size, None);
                assert_eq!(bwlimit, None);
            }
            _ => panic!("Expected Dump command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_dump_command_with_params() {
        let parser = MemcachedParser::new();

        // Test dump with all parameters
        let input = b"dump 1000 0 2 50000\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        match cmd {
            MemcachedCommand::Dump {
                wait,
                partition,
                partition_size,
                bwlimit,
            } => {
                assert_eq!(wait, Some(1000));
                assert_eq!(partition, Some(0));
                assert_eq!(partition_size, Some(2));
                assert_eq!(bwlimit, Some(50000));
            }
            _ => panic!("Expected Dump command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_parse_dump_command_invalid_partition() {
        let parser = MemcachedParser::new();

        // Test dump with invalid partition (partition >= partition_size)
        let input = b"dump 1000 2 2 50000\r\n";
        let result = parser.parse_command(input);
        assert!(result.is_err());
        match result.unwrap_err() {
            MemcachedError::ParseError(msg) => {
                assert_eq!(msg, "partition must be less than partition_size");
            }
            _ => panic!("Expected ParseError"),
        }
    }

    #[test]
    fn test_parse_dump_command_with_wait_only() {
        let parser = MemcachedParser::new();

        // Test dump with only wait parameter
        let input = b"dump 500\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();
        match cmd {
            MemcachedCommand::Dump {
                wait,
                partition,
                partition_size,
                bwlimit,
            } => {
                assert_eq!(wait, Some(500));
                assert_eq!(partition, None);
                assert_eq!(partition_size, None);
                assert_eq!(bwlimit, None);
            }
            _ => panic!("Expected Dump command"),
        }
        assert_eq!(consumed, input.len());
    }

    #[test]
    fn test_format_set_command() {
        let command = MemcachedCommand::Set {
            key: "mykey".to_string(),
            flags: 0,
            exptime: 3600,
            bytes: 5,
            version: None,
            noreply: false,
            value: Bytes::from_static(b"hello"),
        };
        let formatted = MemcachedParser::format_command(&command);
        let expected = b"set mykey 0 3600 5\r\nhello\r\n";
        assert_eq!(formatted, Bytes::from_static(expected));
    }
}
