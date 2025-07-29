# Flare Dump/Restore Protocol

## Dump Command Protocol

The `dump` command retrieves all key-value pairs from flare nodes.

### Request Format
```
dump\r\n
```
or
```
dump <partition>\r\n
```

### Response Format
```
VALUE <key> <flags> <bytes>\r\n
<data>\r\n
VALUE <key> <flags> <bytes>\r\n
<data>\r\n
...
END\r\n
```

Example:
```
VALUE user:1 0 10\r\n
john_doe\r\n
VALUE user:2 0 11\r\n
jane_smith\r\n
END\r\n
```

## Dumpkey Command Protocol

The `dump_key` command retrieves all keys (without values) from flare nodes.

### Request Format
```
dump_key\r\n
```
or
```
dump_key <partition>\r\n
```

### Response Format
```
KEY <key>\r\n
KEY <key>\r\n
...
END\r\n
```

Example:
```
KEY user:1\r\n
KEY user:2\r\n
KEY session:abc\r\n
END\r\n
```

## Restore Command Protocol

The `restore` command sends data back to flare nodes using SET commands.

### Request Format
For each key-value pair:
```
set <key> <flags> <exptime> <bytes>\r\n
<data>\r\n
```

### Response Format
For each SET command:
```
STORED\r\n
```
or
```
SERVER_ERROR <error message>\r\n
```

### Dump File Format for Restore

The dump file format expected by restore command:
```
VALUE <key> <flags> <bytes>\r\n
<data>\r\n
VALUE <key> <flags> <bytes>\r\n
<data>\r\n
...
```

Note: The END marker is not included in dump files for restore.

## Implementation Notes

1. The dump command should handle large datasets by streaming results
2. The restore command should:
   - Parse VALUE lines from dump files
   - Convert them to SET commands (with exptime=0)
   - Handle errors gracefully
   - Support filtering (include/exclude patterns)
3. Binary data should be handled correctly
4. Line endings must be \r\n (CRLF) as per memcached protocol