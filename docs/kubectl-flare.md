# kubectl-flare Plugin

kubectl-flare is a kubectl plugin that allows you to run flare-tools commands directly on the flare index server pod without manually exec'ing into the pod. It automatically finds the index server pod and executes flare-admin or flare-stats commands within the container.

## Installation

### Manual Installation

1. Build and install the plugin:
```bash
./scripts/install-kubectl-plugin.sh
```

2. Verify installation:
```bash
kubectl plugin list | grep flare
```

### Using Krew (when published)

```bash
kubectl krew install flare
```

## Usage

The plugin automatically finds the flare index server pod and executes commands on it.

### Basic Commands

```bash
# List all nodes
kubectl flare admin list

# Show cluster statistics
kubectl flare stats nodes

# Ping the index server
kubectl flare admin ping

# Ping a specific node
kubectl flare admin ping node-0.flared.default.svc.cluster.local:13301

# Add a slave node
kubectl flare admin slave node-2.flared.default.svc.cluster.local:13301 --force

# Set node as master
kubectl flare admin master node-2.flared.default.svc.cluster.local:13301 --force

# Reconstruct a node
kubectl flare admin reconstruct node-2.flared.default.svc.cluster.local:13301 --force

# Show index server status
kubectl flare admin index

# Dump data
kubectl flare admin dump

# Show help
kubectl flare --help
kubectl flare admin --help
kubectl flare stats --help
```

### Specifying Namespace and Pod

By default, the plugin looks for the pod `index-0` (using label `statefulset.kubernetes.io/pod-name=index-0`) in the `default` namespace with container `flarei`.

```bash
# Use a different namespace
kubectl flare -n my-namespace admin list

# Use a different pod selector
kubectl flare --pod-selector=component=index-server admin list

# Use a different container name
kubectl flare --container=flarei admin list
```

### Command Mapping

The plugin supports two main command groups:

1. **admin** - Maps to flare-admin commands
   ```bash
   kubectl flare admin <command> [args]
   # Equivalent to: kubectl exec <pod> -- flare-admin <command> [args]
   ```

2. **stats** - Maps to flare-stats commands
   ```bash
   kubectl flare stats <command> [args]
   # Equivalent to: kubectl exec <pod> -- flare-stats <command> [args]
   ```

### Examples

```bash
# Check cluster health
kubectl flare admin ping --wait

# Balance cluster with specific values
kubectl flare admin balance node-0.flared.default.svc.cluster.local:13301:1024 node-1.flared.default.svc.cluster.local:13301:2048 --force

# Turn down a node
kubectl flare admin down node-2.flared.default.svc.cluster.local:13301 --force

# Activate a node
kubectl flare admin activate node-2.flared.default.svc.cluster.local:13301 --force

# Remove a node
kubectl flare admin remove node-2.flared.default.svc.cluster.local:13301 --force

# Dump keys with partition filter
kubectl flare admin dumpkey --partition 0

# Show thread pool status
kubectl flare admin threads

# Verify cluster configuration
kubectl flare admin verify
```

## Troubleshooting

### Pod Not Found

If the plugin can't find the index server pod:

1. Check the pod exists:
   ```bash
   kubectl get pods | grep index
   # or
   kubectl get pods -l statefulset.kubernetes.io/pod-name=index-0
   ```

2. Use correct namespace:
   ```bash
   kubectl flare -n correct-namespace admin list
   ```

3. Use correct pod selector:
   ```bash
   kubectl get pods --show-labels
   kubectl flare --pod-selector=your-label=value admin list
   ```

### Command Not Found

If kubectl doesn't recognize the flare plugin:

1. Ensure the plugin is in PATH:
   ```bash
   which kubectl-flare
   ```

2. Check kubectl can find it:
   ```bash
   kubectl plugin list
   ```

3. Reinstall the plugin:
   ```bash
   ./scripts/install-kubectl-plugin.sh
   ```

## Development

To build the plugin:
```bash
go build -o kubectl-flare ./cmd/kubectl-flare
```

To test locally without installing:
```bash
./kubectl-flare admin list
```

## Working Example Output

```bash
# List all nodes in the cluster
$ kubectl flare admin list
node                           partition  role       state      balance
node-1.flared.default.svc.cluster.local:13301 0          master     active     1      
node-2.flared.default.svc.cluster.local:13301 -          proxy      active     0      
node-0.flared.default.svc.cluster.local:13301 1          master     active     1

# Show node statistics
$ kubectl flare stats nodes
hostname:port	state	role	partition	balance	items	conn	behind	hit	size	uptime	version
node-0.flared.default.svc.cluster.local:13301	active	master	1	1	0	16	0	0	0	0s	1.3.4
node-1.flared.default.svc.cluster.local:13301	active	master	0	1	0	17	0	0	0	0s	1.3.4
node-2.flared.default.svc.cluster.local:13301	active	proxy	-1	0	0	18	0	0	0	0s	1.3.4

# Ping a node
$ kubectl flare admin ping
alive: :13300
```

## Default Configuration

- **Default namespace**: `default`
- **Default pod selector**: `statefulset.kubernetes.io/pod-name=index-0`
- **Default container**: `flarei`
- **Default index server port**: `13300` (flare-tools v1.0.0+)

Note: The flare cluster uses port 13300 for the index server (flarei) and port 13301 for data nodes (flared).