# Flare Tools (Rust Implementation)

This is a Rust implementation of flare-tools for managing memcached-compatible flare clusters.

## Features

- **Protocol Support**: Full implementation of memcached protocol with flare-specific extensions
- **Admin Tool**: Complete `flare-admin` CLI with all administrative commands
- **Kubernetes Integration**: `kubectl-flare` plugin for managing clusters in Kubernetes
- **Type Safety**: Leverages Rust's type system for robust protocol handling
- **Performance**: Native binary with minimal runtime overhead

## Building

```bash
cargo build --release
```

## Installation

```bash
# Install flare-admin
cargo install --path . --bin flare-admin

# Install kubectl-flare
cargo install --path . --bin kubectl-flare
```

## Usage

### flare-admin

Basic cluster administration:

```bash
# Ping nodes
flare-admin ping localhost:12121

# Show cluster status
flare-admin stats

# List cluster nodes
flare-admin list

# Set node as master
flare-admin master --force server1:12121:1:0

# Set node as slave
flare-admin slave --force server2:12122:1:0

# Dump data from all master nodes
flare-admin dump --all --output backup.dump

# Restore data
flare-admin restore server1:12121 --input backup.dump

# Reconstruct all nodes
flare-admin reconstruct --all --force

# Verify cluster health
flare-admin verify

# Generate index XML
flare-admin index

# Show thread status
flare-admin threads server1:12121

# Monitor cluster with flare-stats
flare-stats --qps --count 5 --wait 1
```

### kubectl-flare

For Kubernetes deployments:

```bash
# Run flare-admin commands on the cluster
kubectl flare admin stats
kubectl flare admin list
kubectl flare admin master --force server1:12121:1:0

# Specify namespace and pod selector
kubectl flare -n flare-system --pod-selector app=flare-index admin stats
```

## Protocol Implementation

The implementation includes:

- **Memcached Protocol**: Complete memcached protocol parser with all standard commands
- **Flare Extensions**: 
  - `dump_key` - Dump keys from partitions
  - `node` commands - Node management (role, state, remove, sync)
  - `kill` - Thread management
  - Extended `dump` with bandwidth limiting

## Architecture

```
src/
├── protocol/
│   ├── memcached.rs    # Core memcached protocol
│   └── flare.rs        # Flare-specific extensions
├── client/
│   └── mod.rs          # Flare client library
├── bin/
│   ├── flare-admin.rs  # CLI administration tool
│   └── kubectl-flare.rs # Kubernetes plugin
└── lib.rs              # Library exports
```

## Commands Supported

All original flare-admin commands are implemented:

- ✅ `ping` - Test node connectivity
- ✅ `stats` - Show cluster statistics  
- ✅ `list` - List cluster nodes  
- ✅ `master` - Configure master nodes (with flush_all)
- ✅ `slave` - Configure slave nodes (with flush_all)
- ✅ `balance` - Adjust node balance
- ✅ `down` - Mark nodes as down
- ✅ `remove` - Remove nodes from cluster
- ✅ `dump` - Export data from nodes
- ✅ `dumpkey` - Export keys from nodes
- ✅ `restore` - Import data to nodes (with VALUE parsing)
- ✅ `reconstruct` - Reconstruct node data (with flush_all)
- ✅ `verify` - Verify cluster consistency (comprehensive checks)
- ✅ `index` - Generate index XML (boost serialization format)
- ✅ `threads` - Show thread status

Additional features:
- ✅ `flare-stats` - Dedicated statistics monitoring tool
- ✅ Dry-run mode for all destructive operations
- ✅ Force mode to skip confirmations
- ✅ Comprehensive error handling and validation

## Testing

```bash
# Run unit tests
cargo test

# Run with verbose output
cargo test -- --nocapture

# Test specific module
cargo test protocol::flare
```

## Development

The codebase follows Rust best practices:

- **Error Handling**: Uses `thiserror` for structured error types
- **CLI**: Built with `clap` for robust argument parsing  
- **Async Ready**: Optional tokio support for async operations
- **Memory Safe**: No unsafe code, leverages Rust's ownership system
- **Type Safe**: Strong typing prevents protocol parsing errors

## License

MIT License