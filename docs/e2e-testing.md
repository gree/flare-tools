# E2E Testing Guide for Flare Tools

This document describes how to run end-to-end (e2e) tests for the Go implementation of flare-tools.

## Overview

There are two types of e2e tests available:

1. **Mock Server Tests** - Run against a mock flare server (fast, isolated)
2. **Kubernetes Cluster Tests** - Run against a real flare cluster in Kubernetes (comprehensive, realistic)

## Prerequisites

### For Mock Server Tests
- Go 1.21 or later
- No external dependencies

### For Kubernetes Cluster Tests
- Kubernetes cluster with flare deployed
- kubectl configured to access the cluster
- Docker (for building Linux binaries)

## Running Mock Server Tests

These tests use a mock flare server and test basic command functionality:

```bash
# Run all mock-based e2e tests
go test -v ./test/e2e

# Run specific test
go test -v ./test/e2e -run TestFlareStatsE2E

# Run with race detection
go test -race -v ./test/e2e
```

### Mock Test Coverage

The mock tests cover:
- ✅ flare-stats basic functionality
- ✅ flare-stats with QPS
- ✅ flare-admin ping
- ✅ flare-admin stats  
- ✅ flare-admin list
- ✅ Help commands
- ✅ Error handling
- ✅ Environment variables
- ⚠️ Master/Slave/Reconstruct (limited due to flush_all requirements)

## Running Kubernetes Cluster Tests

These tests run against a real flare cluster and provide comprehensive validation.

### Step 1: Deploy Flare Cluster

```bash
# Deploy flare cluster using kustomize
kubectl apply -k flare-cluster-k8s/base

# Wait for pods to be ready
kubectl get pods -w
```

### Step 2: Build and Copy Binaries

```bash
# Build Linux binaries
make build-linux
# or manually:
GOOS=linux GOARCH=amd64 go build -o build/flare-admin-linux cmd/flare-admin/main.go
GOOS=linux GOARCH=amd64 go build -o build/flare-stats-linux cmd/flare-stats/main.go

# Copy binaries to cluster nodes
./scripts/copy-to-e2e.sh
```

### Step 3: Run Comprehensive E2E Tests

```bash
# Run all e2e tests on Kubernetes cluster
./scripts/k8s-e2e-test.sh
```

### Step 4: Run Individual Tests

You can also run individual commands manually:

```bash
# Test list command
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list

# Test stats command
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 stats

# Test flare-stats
kubectl exec node-0 -- /usr/local/bin/flare-stats -i flarei.default.svc.cluster.local -p 13300

# Test reconstruct command
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 reconstruct --force node-2.flared.default.svc.cluster.local:13301
```

## Test Script Details

### scripts/k8s-e2e-test.sh

This comprehensive test script covers:

1. **Basic Operations**
   - `list` - Display cluster topology
   - `stats` - Show cluster statistics  
   - `ping` - Test connectivity

2. **flare-stats Tool**
   - Basic stats display
   - QPS (queries per second) metrics

3. **Administrative Commands**
   - `master` - Promote proxy to master
   - `slave` - Convert proxy to slave
   - `balance` - Adjust node balance
   - `down` - Take node down
   - `activate` - Bring node back up
   - `reconstruct` - Rebuild node database

4. **Advanced Features**
   - Environment variable configuration
   - Help command validation
   - Dry-run operations

### scripts/copy-to-e2e.sh

This script:
- Builds Linux binaries if needed
- Copies binaries to all cluster pods
- Sets proper permissions
- Tests basic functionality

## Expected Test Results

### Successful Test Output

```
=== Running E2E tests on Kubernetes flare cluster ===

Test 1: List nodes
node                           partition  role       state      balance
node-0.flared.default.svc.cluster.local:13301 1          master     active     1      
node-1.flared.default.svc.cluster.local:13301 0          master     active     1      
node-2.flared.default.svc.cluster.local:13301 1          slave      active     1      

Test 3: Ping
alive: flarei.default.svc.cluster.local:13300

Test 11: Reconstruct command
Reconstructing nodes...
reconstructing node (node=node-2.flared.default.svc.cluster.local:13301, role=slave)
turning down...
waiting for node to be active again...
started constructing node...
done.
Operation completed successfully
```

### Common Issues and Solutions

#### Issue: "flush_all failed: failed to connect"
**Solution**: Ensure you're running tests from inside a cluster pod where nodes can reach each other:
```bash
kubectl exec node-0 -- /usr/local/bin/flare-admin ...
```

#### Issue: "No proxy node available"
**Solution**: This is expected when all nodes have roles. The test will skip operations requiring proxy nodes.

#### Issue: "Master command test skipped"  
**Solution**: Normal behavior when trying to change an existing master's partition. The validation logic prevents invalid operations.

## Adding New Tests

### Mock Server Tests

Add new tests to `test/e2e/e2e_test.go`:

```go
func TestNewFeatureE2E(t *testing.T) {
    mockServer, err := NewMockFlareServer()
    require.NoError(t, err)
    defer mockServer.Close()
    
    flareAdminPath, _ := buildBinaries(t)
    
    // Add your test logic here
}
```

### Kubernetes Tests

Add new test cases to `scripts/k8s-e2e-test.sh`:

```bash
# Test X: New feature
echo "Test X: New feature"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 new-command
echo
```

## Continuous Integration

For CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Run Mock E2E Tests
  run: go test -v ./test/e2e

- name: Setup Kubernetes
  uses: helm/kind-action@v1

- name: Deploy Flare Cluster  
  run: kubectl apply -k flare-cluster-k8s/base

- name: Run Kubernetes E2E Tests
  run: |
    ./scripts/copy-to-e2e.sh
    ./scripts/k8s-e2e-test.sh
```

## Performance Testing

For load testing, you can run multiple operations:

```bash
# Stress test with multiple stats calls
for i in {1..100}; do
    kubectl exec node-0 -- /usr/local/bin/flare-stats -i flarei.default.svc.cluster.local -p 13300
done

# Test concurrent operations
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 stats &
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list &
wait
```

## Cleanup

After testing:

```bash
# Remove flare cluster
kubectl delete -k flare-cluster-k8s/base

# Clean up local binaries
rm -rf build/
```

## Contributing

When adding new features:

1. Add mock server tests for basic functionality
2. Add Kubernetes tests for integration scenarios  
3. Update this documentation
4. Ensure all existing tests still pass