#[cfg(test)]
mod quit_tests {
    use super::super::memcached::{MemcachedCommand, MemcachedParser};

    #[test]
    fn test_quit_command_flow() {
        let parser = MemcachedParser::new();

        // Simulate a connection with multiple commands ending with QUIT
        let commands: Vec<&[u8]> =
            vec![b"set test 0 0 5\r\nhello\r\n", b"get test\r\n", b"quit\r\n"];

        let mut parsed_commands = Vec::new();

        for cmd in commands {
            match parser.parse_command(cmd) {
                Ok((command, _)) => {
                    parsed_commands.push(command);
                }
                Err(e) => panic!("Failed to parse command: {:?}", e),
            }
        }

        // Verify we have the expected commands
        assert_eq!(parsed_commands.len(), 3);

        // Check that the last command is QUIT
        assert!(matches!(
            parsed_commands.last().unwrap(),
            MemcachedCommand::Quit
        ));
    }

    #[test]
    fn test_quit_command_properties() {
        let parser = MemcachedParser::new();

        // Parse QUIT command
        let input = b"quit\r\n";
        let (command, consumed) = parser.parse_command(input).unwrap();

        // Verify properties
        assert!(matches!(command, MemcachedCommand::Quit));
        assert_eq!(consumed, 6); // "quit\r\n" = 6 bytes

        // QUIT should not have any parameters
        match command {
            MemcachedCommand::Quit => {
                // Good - no parameters
            }
            _ => panic!("Expected Quit command"),
        }
    }
}
