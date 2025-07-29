use super::*;
use bytes::Bytes;

/// Comprehensive tests for all memcached ASCII protocol commands
/// Based on the official memcached protocol specification

#[cfg(test)]
mod comprehensive_protocol_tests {
    use super::*;

    fn new_parser() -> MemcachedParser {
        MemcachedParser::new()
    }

    // Storage Commands Tests
    #[test]
    fn test_set_command_basic() {
        let parser = new_parser();
        let input = b"set mykey 0 0 5\r\nhello\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        assert_eq!(consumed, input.len());
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
                assert_eq!(exptime, 0);
                assert_eq!(bytes, 5);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("hello"));
            }
            _ => panic!("Expected Set command"),
        }
    }

    #[test]
    fn test_set_command_with_flags_and_exptime() {
        let parser = new_parser();
        let input = b"set key 123 3600 4\r\ntest\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        assert_eq!(consumed, input.len());
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
                assert_eq!(key, "key");
                assert_eq!(flags, 123);
                assert_eq!(exptime, 3600);
                assert_eq!(bytes, 4);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("test"));
            }
            _ => panic!("Expected Set command"),
        }
    }

    #[test]
    fn test_set_command_noreply() {
        let parser = new_parser();
        let input = b"set key 0 0 5 noreply\r\nhello\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Set { noreply, .. } => {
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected Set command"),
        }
    }

    #[test]
    fn test_add_command() {
        let parser = new_parser();
        let input = b"add newkey 0 0 3\r\nfoo\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Add {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            } => {
                assert_eq!(key, "newkey");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 0);
                assert_eq!(bytes, 3);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("foo"));
            }
            _ => panic!("Expected Add command"),
        }
    }

    #[test]
    fn test_replace_command() {
        let parser = new_parser();
        let input = b"replace existingkey 42 1000 3\r\nbar\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Replace {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            } => {
                assert_eq!(key, "existingkey");
                assert_eq!(flags, 42);
                assert_eq!(exptime, 1000);
                assert_eq!(bytes, 3);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("bar"));
            }
            _ => panic!("Expected Replace command"),
        }
    }

    #[test]
    fn test_append_command() {
        let parser = new_parser();
        let input = b"append key 0 0 5\r\nworld\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Append {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            } => {
                assert_eq!(key, "key");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 0);
                assert_eq!(bytes, 5);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("world"));
            }
            _ => panic!("Expected Append command"),
        }
    }

    #[test]
    fn test_prepend_command() {
        let parser = new_parser();
        let input = b"prepend key 0 0 6\r\nhello \r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Prepend {
                key,
                flags,
                exptime,
                bytes,
                noreply,
                value,
            } => {
                assert_eq!(key, "key");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 0);
                assert_eq!(bytes, 6);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("hello "));
            }
            _ => panic!("Expected Prepend command"),
        }
    }

    #[test]
    fn test_cas_command() {
        let parser = new_parser();
        let input = b"cas key 0 0 5 12345\r\nhello\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

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
                assert_eq!(key, "key");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 0);
                assert_eq!(bytes, 5);
                assert_eq!(cas_unique, 12345);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from("hello"));
            }
            _ => panic!("Expected CAS command"),
        }
    }

    #[test]
    fn test_cas_command_noreply() {
        let parser = new_parser();
        let input = b"cas key 1 3600 4 98765 noreply\r\ndata\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

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
                assert_eq!(key, "key");
                assert_eq!(flags, 1);
                assert_eq!(exptime, 3600);
                assert_eq!(bytes, 4);
                assert_eq!(cas_unique, 98765);
                assert_eq!(noreply, true);
                assert_eq!(value, Bytes::from("data"));
            }
            _ => panic!("Expected CAS command"),
        }
    }

    // Retrieval Commands Tests
    #[test]
    fn test_get_single_key() {
        let parser = new_parser();
        let input = b"get mykey\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        assert_eq!(consumed, input.len());
        match cmd {
            MemcachedCommand::Get { keys } => {
                assert_eq!(keys, vec!["mykey"]);
            }
            _ => panic!("Expected Get command"),
        }
    }

    #[test]
    fn test_get_multiple_keys() {
        let parser = new_parser();
        let input = b"get key1 key2 key3 key4\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Get { keys } => {
                assert_eq!(keys, vec!["key1", "key2", "key3", "key4"]);
            }
            _ => panic!("Expected Get command"),
        }
    }

    #[test]
    fn test_gets_single_key() {
        let parser = new_parser();
        let input = b"gets mykey\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Gets { keys } => {
                assert_eq!(keys, vec!["mykey"]);
            }
            _ => panic!("Expected Gets command"),
        }
    }

    #[test]
    fn test_gets_multiple_keys() {
        let parser = new_parser();
        let input = b"gets key1 key2\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Gets { keys } => {
                assert_eq!(keys, vec!["key1", "key2"]);
            }
            _ => panic!("Expected Gets command"),
        }
    }

    // GAT (Get And Touch) Commands Tests
    #[test]
    fn test_gat_command() {
        let parser = new_parser();
        let input = b"gat 3600 key1 key2\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Gat { exptime, keys } => {
                assert_eq!(exptime, 3600);
                assert_eq!(keys, vec!["key1", "key2"]);
            }
            _ => panic!("Expected GAT command"),
        }
    }

    #[test]
    fn test_gats_command() {
        let parser = new_parser();
        let input = b"gats 7200 mykey\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Gats { exptime, keys } => {
                assert_eq!(exptime, 7200);
                assert_eq!(keys, vec!["mykey"]);
            }
            _ => panic!("Expected GATS command"),
        }
    }

    // Deletion Commands Tests
    #[test]
    fn test_delete_command() {
        let parser = new_parser();
        let input = b"delete mykey\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Delete { key, noreply } => {
                assert_eq!(key, "mykey");
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected Delete command"),
        }
    }

    #[test]
    fn test_delete_command_noreply() {
        let parser = new_parser();
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

    // Arithmetic Commands Tests
    #[test]
    fn test_incr_command() {
        let parser = new_parser();
        let input = b"incr counter 5\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Incr {
                key,
                value,
                noreply,
            } => {
                assert_eq!(key, "counter");
                assert_eq!(value, 5);
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected Incr command"),
        }
    }

    #[test]
    fn test_incr_command_noreply() {
        let parser = new_parser();
        let input = b"incr counter 10 noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Incr {
                key,
                value,
                noreply,
            } => {
                assert_eq!(key, "counter");
                assert_eq!(value, 10);
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected Incr command"),
        }
    }

    #[test]
    fn test_decr_command() {
        let parser = new_parser();
        let input = b"decr counter 3\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Decr {
                key,
                value,
                noreply,
            } => {
                assert_eq!(key, "counter");
                assert_eq!(value, 3);
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected Decr command"),
        }
    }

    #[test]
    fn test_decr_command_noreply() {
        let parser = new_parser();
        let input = b"decr counter 1 noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Decr {
                key,
                value,
                noreply,
            } => {
                assert_eq!(key, "counter");
                assert_eq!(value, 1);
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected Decr command"),
        }
    }

    // Touch Command Tests
    #[test]
    fn test_touch_command() {
        let parser = new_parser();
        let input = b"touch mykey 3600\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Touch {
                key,
                exptime,
                noreply,
            } => {
                assert_eq!(key, "mykey");
                assert_eq!(exptime, 3600);
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected Touch command"),
        }
    }

    #[test]
    fn test_touch_command_noreply() {
        let parser = new_parser();
        let input = b"touch mykey 7200 noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Touch {
                key,
                exptime,
                noreply,
            } => {
                assert_eq!(key, "mykey");
                assert_eq!(exptime, 7200);
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected Touch command"),
        }
    }

    // Statistics Commands Tests
    #[test]
    fn test_stats_command_no_args() {
        let parser = new_parser();
        let input = b"stats\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Stats { args } => {
                assert_eq!(args, None);
            }
            _ => panic!("Expected Stats command"),
        }
    }

    #[test]
    fn test_stats_command_with_args() {
        let parser = new_parser();
        let input = b"stats slabs\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Stats { args } => {
                assert_eq!(args, Some("slabs".to_string()));
            }
            _ => panic!("Expected Stats command"),
        }
    }

    #[test]
    fn test_stats_command_multiple_args() {
        let parser = new_parser();
        let input = b"stats items 1\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Stats { args } => {
                assert_eq!(args, Some("items 1".to_string()));
            }
            _ => panic!("Expected Stats command"),
        }
    }

    // Flush Commands Tests
    #[test]
    fn test_flush_all_command() {
        let parser = new_parser();
        let input = b"flush_all\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::FlushAll { delay, noreply } => {
                assert_eq!(delay, None);
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected FlushAll command"),
        }
    }

    #[test]
    fn test_flush_all_command_with_delay() {
        let parser = new_parser();
        let input = b"flush_all 300\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::FlushAll { delay, noreply } => {
                assert_eq!(delay, Some(300));
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected FlushAll command"),
        }
    }

    #[test]
    fn test_flush_all_command_noreply() {
        let parser = new_parser();
        let input = b"flush_all noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::FlushAll { delay, noreply } => {
                assert_eq!(delay, None);
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected FlushAll command"),
        }
    }

    #[test]
    fn test_flush_all_command_delay_noreply() {
        let parser = new_parser();
        let input = b"flush_all 600 noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::FlushAll { delay, noreply } => {
                assert_eq!(delay, Some(600));
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected FlushAll command"),
        }
    }

    // Administrative Commands Tests
    #[test]
    fn test_verbosity_command() {
        let parser = new_parser();
        let input = b"verbosity 2\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Verbosity { level, noreply } => {
                assert_eq!(level, 2);
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected Verbosity command"),
        }
    }

    #[test]
    fn test_verbosity_command_noreply() {
        let parser = new_parser();
        let input = b"verbosity 1 noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Verbosity { level, noreply } => {
                assert_eq!(level, 1);
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected Verbosity command"),
        }
    }

    #[test]
    fn test_cache_memlimit_command() {
        let parser = new_parser();
        let input = b"cache_memlimit 128\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::CacheMemlimit { memlimit, noreply } => {
                assert_eq!(memlimit, 128);
                assert_eq!(noreply, false);
            }
            _ => panic!("Expected CacheMemlimit command"),
        }
    }

    #[test]
    fn test_cache_memlimit_command_noreply() {
        let parser = new_parser();
        let input = b"cache_memlimit 256 noreply\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::CacheMemlimit { memlimit, noreply } => {
                assert_eq!(memlimit, 256);
                assert_eq!(noreply, true);
            }
            _ => panic!("Expected CacheMemlimit command"),
        }
    }

    // Version and Quit Commands Tests
    #[test]
    fn test_version_command() {
        let parser = new_parser();
        let input = b"version\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        assert_eq!(consumed, input.len());
        match cmd {
            MemcachedCommand::Version => {
                // Success
            }
            _ => panic!("Expected Version command"),
        }
    }

    #[test]
    fn test_quit_command() {
        let parser = new_parser();
        let input = b"quit\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        assert_eq!(consumed, input.len());
        match cmd {
            MemcachedCommand::Quit => {
                // Success
            }
            _ => panic!("Expected Quit command"),
        }
    }

    // Response Formatting Tests
    #[test]
    fn test_format_stored_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Stored;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("STORED\r\n"));
    }

    #[test]
    fn test_format_not_stored_response() {
        let parser = new_parser();
        let response = MemcachedResponse::NotStored;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("NOT_STORED\r\n"));
    }

    #[test]
    fn test_format_exists_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Exists;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("EXISTS\r\n"));
    }

    #[test]
    fn test_format_not_found_response() {
        let parser = new_parser();
        let response = MemcachedResponse::NotFound;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("NOT_FOUND\r\n"));
    }

    #[test]
    fn test_format_deleted_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Deleted;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("DELETED\r\n"));
    }

    #[test]
    fn test_format_touched_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Touched;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("TOUCHED\r\n"));
    }

    #[test]
    fn test_format_ok_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Ok;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("OK\r\n"));
    }

    #[test]
    fn test_format_error_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Error("invalid command".to_string());
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("ERROR invalid command\r\n"));
    }

    #[test]
    fn test_format_client_error_response() {
        let parser = new_parser();
        let response = MemcachedResponse::ClientError("bad syntax".to_string());
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("CLIENT_ERROR bad syntax\r\n"));
    }

    #[test]
    fn test_format_server_error_response() {
        let parser = new_parser();
        let response = MemcachedResponse::ServerError("out of memory".to_string());
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("SERVER_ERROR out of memory\r\n"));
    }

    #[test]
    fn test_format_value_response_without_cas() {
        let parser = new_parser();
        let response = MemcachedResponse::Value {
            key: "mykey".to_string(),
            flags: 42,
            bytes: 5,
            cas_unique: None,
            data: Bytes::from("hello"),
        };
        let formatted = parser.format_response(&response);
        let expected = b"VALUE mykey 42 5\r\nhello\r\n";
        assert_eq!(formatted, Bytes::from(&expected[..]));
    }

    #[test]
    fn test_format_value_response_with_cas() {
        let parser = new_parser();
        let response = MemcachedResponse::Value {
            key: "mykey".to_string(),
            flags: 0,
            bytes: 4,
            cas_unique: Some(12345),
            data: Bytes::from("test"),
        };
        let formatted = parser.format_response(&response);
        let expected = b"VALUE mykey 0 4 12345\r\ntest\r\n";
        assert_eq!(formatted, Bytes::from(&expected[..]));
    }

    #[test]
    fn test_format_end_response() {
        let parser = new_parser();
        let response = MemcachedResponse::End;
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("END\r\n"));
    }

    #[test]
    fn test_format_version_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Version("1.6.9".to_string());
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("VERSION 1.6.9\r\n"));
    }

    #[test]
    fn test_format_stat_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Stat {
            name: "uptime".to_string(),
            value: "12345".to_string(),
        };
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("STAT uptime 12345\r\n"));
    }

    #[test]
    fn test_format_stat_end_response() {
        let parser = new_parser();
        let response = MemcachedResponse::Stat {
            name: "".to_string(),
            value: "".to_string(),
        };
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("END\r\n"));
    }

    #[test]
    fn test_format_incr_decr_response() {
        let parser = new_parser();
        let response = MemcachedResponse::IncrDecr(42);
        let formatted = parser.format_response(&response);
        assert_eq!(formatted, Bytes::from("42\r\n"));
    }

    // Edge Cases and Error Handling Tests
    #[test]
    fn test_invalid_command() {
        let parser = new_parser();
        let input = b"invalid_cmd\r\n";
        let result = parser.parse_command(input);
        assert!(result.is_err());
        match result.unwrap_err() {
            MemcachedError::InvalidCommand => {
                // Expected
            }
            _ => panic!("Expected InvalidCommand error"),
        }
    }

    #[test]
    fn test_malformed_set_command_missing_bytes() {
        let parser = new_parser();
        let input = b"set key 0 0\r\n";
        let result = parser.parse_command(input);
        assert!(result.is_err());
    }

    #[test]
    fn test_malformed_set_command_invalid_flags() {
        let parser = new_parser();
        let input = b"set key invalid 0 5\r\nhello\r\n";
        let result = parser.parse_command(input);
        assert!(result.is_err());
    }

    #[test]
    fn test_malformed_incr_command_invalid_value() {
        let parser = new_parser();
        let input = b"incr key invalid\r\n";
        let result = parser.parse_command(input);
        assert!(result.is_err());
    }

    #[test]
    fn test_empty_key_handling() {
        let parser = new_parser();
        let input = b"get\r\n";
        let result = parser.parse_command(input);
        assert!(result.is_err());
    }

    #[test]
    fn test_zero_length_value() {
        let parser = new_parser();
        let input = b"set key 0 0 0\r\n\r\n";
        let (cmd, consumed) = parser.parse_command(input).unwrap();

        assert_eq!(consumed, input.len());
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
                assert_eq!(key, "key");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 0);
                assert_eq!(bytes, 0);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from(""));
            }
            _ => panic!("Expected Set command"),
        }
    }

    #[test]
    fn test_large_values() {
        let parser = new_parser();
        let large_value = "x".repeat(1000);
        let input = format!("set key 0 0 1000\r\n{}\r\n", large_value);
        let (cmd, consumed) = parser.parse_command(input.as_bytes()).unwrap();

        assert_eq!(consumed, input.len());
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
                assert_eq!(key, "key");
                assert_eq!(flags, 0);
                assert_eq!(exptime, 0);
                assert_eq!(bytes, 1000);
                assert_eq!(noreply, false);
                assert_eq!(value, Bytes::from(large_value));
            }
            _ => panic!("Expected Set command"),
        }
    }

    #[test]
    fn test_binary_data_handling() {
        let parser = new_parser();
        let binary_data = vec![0u8, 1, 2, 3, 255, 254, 253];
        let mut input = b"set key 0 0 7\r\n".to_vec();
        input.extend_from_slice(&binary_data);
        input.extend_from_slice(b"\r\n");

        let (cmd, consumed) = parser.parse_command(&input).unwrap();
        assert_eq!(consumed, input.len());

        match cmd {
            MemcachedCommand::Set { value, .. } => {
                assert_eq!(value, Bytes::from(binary_data));
            }
            _ => panic!("Expected Set command"),
        }
    }

    #[test]
    fn test_max_cas_value() {
        let parser = new_parser();
        let input = b"cas key 0 0 5 18446744073709551615\r\nhello\r\n";
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Cas { cas_unique, .. } => {
                assert_eq!(cas_unique, u64::MAX);
            }
            _ => panic!("Expected CAS command"),
        }
    }

    #[test]
    fn test_unix_timestamp_expiration() {
        let parser = new_parser();
        let unix_timestamp = 1640995200u32; // Jan 1, 2022
        let input = format!("set key 0 {} 5\r\nhello\r\n", unix_timestamp);
        let (cmd, _) = parser.parse_command(input.as_bytes()).unwrap();

        match cmd {
            MemcachedCommand::Set { exptime, .. } => {
                assert_eq!(exptime, unix_timestamp);
            }
            _ => panic!("Expected Set command"),
        }
    }

    #[test]
    fn test_case_sensitivity() {
        let parser = new_parser();
        let input = b"SET key 0 0 5\r\nhello\r\n"; // Uppercase command
        let result = parser.parse_command(input);
        assert!(result.is_err()); // Commands are case-sensitive and must be lowercase
    }

    #[test]
    fn test_whitespace_handling() {
        let parser = new_parser();
        let input = b"get   key1    key2   \r\n"; // Multiple spaces
        let (cmd, _) = parser.parse_command(input).unwrap();

        match cmd {
            MemcachedCommand::Get { keys } => {
                assert_eq!(keys, vec!["key1", "key2"]);
            }
            _ => panic!("Expected Get command"),
        }
    }
}
