# flare-tools (Rust Implementation)

A Rust implementation of flare-tools, a collection of command line tools to maintain a flare cluster.

## Overview

This is a complete rewrite of the original Ruby-based flare-tools in Rust, providing:

- **Performance**: Faster execution and lower memory usage
- **Safety**: Memory safety and thread safety guaranteed by Rust
- **Deployment**: Single binary deployment with no runtime dependencies
- **Maintainability**: Strong typing and comprehensive test coverage
- **Compatibility**: Full compatibility with the original Ruby implementation

## Tools

### flare-stats

A command line tool for acquiring statistics of flare nodes.

```bash
flare-stats --index-server=flare1.example.com
```

### flare-admin

A command line tool for maintaining flare clusters with various subcommands:

```bash
flare-admin [subcommand] [options] [arguments]
```

#### Available Subcommands

- `ping` - Check if nodes are alive
- `stats` - Show cluster statistics
- `list` - List nodes in the cluster
- `master` - Create master partitions
- `slave` - Create slave nodes
- `balance` - Set node balance values
- `down` - Turn down nodes
- `reconstruct` - Reconstruct node databases
- `remove` - Remove nodes from cluster
- `dump` - Dump data from nodes
- `dumpkey` - Dump keys from nodes
- `restore` - Restore data to nodes
- `index` - Generate index XML
- `threads` - Show thread status
- `verify` - Verify cluster integrity

### flare-cluster-repl

A command line tool for configuring cluster replication settings:

```bash
flare-cluster-repl [environment] [config-file]
```

Supports both Docker Compose and AWS environments for updating flared.conf files with replication settings.

## Installation

### Pre-built Binaries

Download the latest binaries from the [releases page](https://github.com/gree/flare-tools/releases).

### From Source

```bash
# Clone the repository
git clone https://github.com/gree/flare-tools.git
cd flare-tools

# Build and install
cargo build --release
cargo install --path .
```

### Using Cargo

```bash
cargo install flare-tools
```

### Docker

```bash
docker build -t flare-tools .
docker run --rm flare-tools flare-admin --help
```

## Configuration

### Environment Variables

- `FLARE_INDEX_SERVER` - Index server hostname or hostname:port
- `FLARE_INDEX_SERVER_PORT` - Index server port (default: 12120)

### Command Line Options

Common options available for all commands:

- `--index-server` - Index server hostname
- `--index-server-port` - Index server port
- `--debug` - Enable debug mode
- `--warn` - Turn on warnings
- `--dry-run` - Dry run mode (flare-admin only)
- `--force` - Skip confirmation prompts
- `--help` - Show help message

## Usage Examples

### Basic Statistics

```bash
# Show cluster statistics
flare-stats --index-server=flare1.example.com

# Show statistics with QPS information
flare-stats --index-server=flare1.example.com --qps

# Repeat statistics every 5 seconds, 10 times
flare-stats --index-server=flare1.example.com --wait=5 --count=10
```

### Cluster Management

```bash
# Ping nodes
flare-admin ping --index-server=flare1.example.com

# List nodes in cluster
flare-admin list --index-server=flare1.example.com

# Create master partition
flare-admin master --index-server=flare1.example.com newmaster:12131:1:1

# Create slave nodes
flare-admin slave --index-server=flare1.example.com newslave:12132:1:0

# Set node balance
flare-admin balance --index-server=flare1.example.com node1:12131:3
```

### Data Operations

```bash
# Dump data from all master nodes
flare-admin dump --index-server=flare1.example.com --all --output=backup.data

# Restore data to node
flare-admin restore --index-server=flare1.example.com --input=backup.data node1:12131
```

## Development

### Prerequisites

- Rust 1.75 or later
- Docker (for integration/e2e tests)
- Docker Compose

### Building

```bash
# Build binaries
cargo build --release

# Run tests
cargo test

# Run all tests with integration tests
cargo test --all-features

# Generate coverage report
cargo tarpaulin
```

### Testing

**Important**: Tests run with single thread by default (configured in `.cargo/config.toml`) to prevent Docker container conflicts when running integration tests.

#### Unit Tests

```bash
cargo test
```

#### Integration Tests

```bash
# Run flare-admin integration tests
cargo test flare_admin_integration_test -- --nocapture

# Run flare-cluster-repl integration tests
cargo test flare_cluster_repl_integration_test -- --nocapture
```

#### E2E Testing Setup

Before running e2e tests, you need to set up your environment:

1. **Update /etc/hosts** - Add these entries to `/etc/hosts`:
   ```
   # Single cluster setup
   127.0.0.1	flarei
   127.0.0.1	flared1
   127.0.0.1	flared2
   127.0.0.1	flared3
   127.0.0.1	flared4

   # Multi-cluster setup (for flare-cluster-repl testing)
   127.0.0.1	flarei-prod
   127.0.0.1	flare-prod-master-1
   127.0.0.1	flare-prod-master-2
   127.0.0.1	flare-prod-slave-1
   127.0.0.1	flare-prod-slave-2
   127.0.0.1	flarei-staging
   127.0.0.1	flare-staging-master-1
   127.0.0.1	flare-staging-slave-1
   ```

2. **Start test clusters**:
   ```bash
   # For single cluster tests
   docker-compose up -d

   # For multi-cluster tests
   docker-compose -f docker-compose-multi-cluster.yml up -d
   ```

3. **Run e2e tests**:
   ```bash
   # Test flare-admin with single cluster
   cargo test flare_admin_integration_test -- --nocapture

   # Test flare-cluster-repl with multi-cluster
   cargo test flare_cluster_repl_integration_test -- --nocapture
   ```

4. **Clean up**:
   ```bash
   # Stop single cluster
   docker-compose down

   # Stop multi-cluster
   docker-compose -f docker-compose-multi-cluster.yml down
   ```

#### Test Environment Details

- **Unit tests**: Mock server implementation, no external dependencies
- **Integration tests**: Real flare cluster using Docker containers with DNS names
- **E2E tests**: Full cluster topology with master/slave configuration and replication testing

### Code Quality

```bash
# Format code
cargo fmt

# Lint code
cargo clippy

# Check code
cargo check
```

## Project Structure

```
.
├── src/
│   ├── bin/              # Command line applications
│   │   ├── flare-admin.rs      # flare-admin command
│   │   ├── flare-stats.rs      # flare-stats command  
│   │   └── flare-cluster-repl.rs # flare-cluster-repl command
│   ├── lib.rs           # Library root
│   └── modules/         # Internal modules
├── tests/               # Integration tests
│   ├── flare_admin_integration_test.rs
│   └── flare_cluster_repl_integration_test.rs
├── examples/            # Configuration examples
├── docker-compose.yml   # Single cluster setup
├── docker-compose-multi-cluster.yml # Multi-cluster setup
├── Dockerfile           # Docker configuration
├── Cargo.toml          # Rust project configuration
└── Cargo.lock          # Dependency lockfile
```

## Migration from Ruby Version

This Rust implementation maintains full compatibility with the original Ruby version:

- All command line options are preserved
- Output formats are identical
- Environment variable support is maintained
- All subcommands and their behaviors are replicated

### Key Improvements

1. **Performance**: Significantly faster startup and execution
2. **Safety**: Memory safety and thread safety guaranteed by Rust
3. **Memory Usage**: Lower memory footprint
4. **Deployment**: Single binary with no runtime dependencies
5. **Error Handling**: More robust error handling and reporting
6. **Testing**: Comprehensive test coverage including e2e tests
7. **Maintenance**: Easier to maintain and extend

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

MIT-style license - see LICENSE file for details.

## Authors

- Original Ruby implementation: Kiyoshi Ikehara <kiyoshi.ikehara@gree.net>  
- Rust implementation: Converted from Ruby with full compatibility

Copyright (C) GREE, Inc. 2011-2024.