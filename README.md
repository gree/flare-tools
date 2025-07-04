# flare-tools (Go Implementation)

[![CI](https://github.com/gree/flare-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/gree/flare-tools/actions/workflows/ci.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/gree/flare-tools)](https://goreportcard.com/report/github.com/gree/flare-tools)
[![Coverage](https://codecov.io/gh/gree/flare-tools/branch/master/graph/badge.svg)](https://codecov.io/gh/gree/flare-tools)

A Go implementation of flare-tools, a collection of command line tools to maintain a flare cluster.

## Overview

This is a complete rewrite of the original Ruby-based flare-tools in Go, providing:

- **Performance**: Faster execution and lower memory usage
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
- `activate` - Activate nodes
- `index` - Generate index XML
- `threads` - Show thread status
- `verify` - Verify cluster integrity

## Installation

### Pre-built Binaries

Download the latest binaries from the [releases page](https://github.com/gree/flare-tools/releases).

### From Source

```bash
# Clone the repository
git clone https://github.com/gree/flare-tools.git
cd flare-tools

# Build and install
make build
make install
```

### Using Go

```bash
go install github.com/gree/flare-tools/cmd/flare-admin@latest
go install github.com/gree/flare-tools/cmd/flare-stats@latest
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

- Go 1.21 or later
- Make
- Docker (optional)

### Building

```bash
# Build binaries
make build

# Build for all platforms
make build-all

# Run tests
make test

# Run all tests (unit + integration + e2e)
make test-all

# Generate coverage report
make coverage
```

### Testing

```bash
# Run unit tests
make test

# Run integration tests
make integration-test

# Run e2e tests (mock server)
go test -v ./test/e2e

# Run comprehensive e2e tests on Kubernetes cluster
./scripts/k8s-e2e-test.sh

# Run all tests
make test-all
```

For detailed testing instructions, see [E2E Testing Guide](docs/e2e-testing.md).

### Code Quality

```bash
# Format code
make fmt

# Vet code
make vet

# Lint code (requires golangci-lint)
make lint

# Development setup
make dev-setup
```

## Project Structure

```
.
├── cmd/                    # Command line applications
│   ├── flare-admin/       # flare-admin command
│   └── flare-stats/       # flare-stats command
├── internal/              # Internal packages
│   ├── admin/            # Admin CLI implementation
│   ├── config/           # Configuration handling
│   ├── flare/            # Flare client implementation
│   └── stats/            # Stats CLI implementation
├── test/                  # Test files
│   ├── e2e/              # End-to-end tests
│   └── integration/      # Integration tests
├── .github/workflows/     # GitHub Actions CI/CD
├── Dockerfile            # Docker configuration
├── Makefile.go           # Go build configuration
└── go.mod               # Go module definition
```

## Migration from Ruby Version

This Go implementation maintains full compatibility with the original Ruby version:

- All command line options are preserved
- Output formats are identical
- Environment variable support is maintained
- All subcommands and their behaviors are replicated

### Key Improvements

1. **Performance**: Significantly faster startup and execution
2. **Memory Usage**: Lower memory footprint
3. **Deployment**: Single binary with no runtime dependencies
4. **Error Handling**: More robust error handling and reporting
5. **Testing**: Comprehensive test coverage including e2e tests
6. **Maintenance**: Easier to maintain and extend

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
- Go implementation: Converted from Ruby with full compatibility

Copyright (C) GREE, Inc. 2011-2024.