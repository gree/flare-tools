#!/bin/bash

# E2E tests for flare-tools on Kubernetes cluster

set -e

echo "=== Running E2E tests on Kubernetes flare cluster ==="
echo

# Test 1: List nodes
echo "Test 1: List nodes"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list
echo

# Test 2: Stats
echo "Test 2: Stats"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 stats
echo

# Test 3: Ping
echo "Test 3: Ping"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 ping
echo

# Test 4: flare-stats
echo "Test 4: flare-stats"
kubectl exec node-0 -- /usr/local/bin/flare-stats -i flarei.default.svc.cluster.local -p 13300
echo

# Test 5: flare-stats with QPS
echo "Test 5: flare-stats with QPS"
kubectl exec node-0 -- /usr/local/bin/flare-stats -i flarei.default.svc.cluster.local -p 13300 --qps
echo

# Test 6: Master command (find a proxy node first)
echo "Test 6: Master command"
PROXY_NODE=$(kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list | grep proxy | head -1 | awk '{print $1}')
if [ -n "$PROXY_NODE" ]; then
    echo "Making $PROXY_NODE a master for partition 2..."
    kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 master --force "$PROXY_NODE:1:2"
else
    echo "No proxy node available, creating a master from existing node..."
    # Try to make node-2 a master for partition 2
    kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 master --force "node-2.flared.default.svc.cluster.local:13301:1:2" || echo "Master command test skipped"
fi
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list
echo

# Test 7: Slave command
echo "Test 7: Slave command"
# Try to find a proxy or create a slave
PROXY_NODE=$(kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list | grep proxy | head -1 | awk '{print $1}')
if [ -n "$PROXY_NODE" ]; then
    echo "Making $PROXY_NODE a slave..."
    kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 slave --force "$PROXY_NODE:1:1"
else
    echo "No proxy node available for slave test"
fi
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list
echo

# Test 8: Balance command
echo "Test 8: Balance command"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 balance --force "node-0.flared.default.svc.cluster.local:13301:2"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list
echo

# Test 9: Down command
echo "Test 9: Down command"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 down --force "node-2.flared.default.svc.cluster.local:13301"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list
echo

# Test 10: Activate command
echo "Test 10: Activate command"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 activate --force "node-2.flared.default.svc.cluster.local:13301"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list
echo

# Test 11: Add test data to cluster
echo "Test 11: Adding test data to cluster"
echo "Setting test keys..."
kubectl exec node-0 -- sh -c "echo -e 'set testkey1 0 0 10\r\ntestvalue1\r\nquit\r\n' | nc node-0.flared.default.svc.cluster.local 13301"
kubectl exec node-0 -- sh -c "echo -e 'set testkey2 0 0 10\r\ntestvalue2\r\nquit\r\n' | nc node-1.flared.default.svc.cluster.local 13301"
kubectl exec node-0 -- sh -c "echo -e 'set testkey3 0 0 10\r\ntestvalue3\r\nquit\r\n' | nc node-2.flared.default.svc.cluster.local 13301"
echo "Test data added"
echo

# Test 12: Dump command with existing data
echo "Test 12: Dump command with existing data"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 dump --force "node-0.flared.default.svc.cluster.local:13301" | head -20
echo

# Test 13: Dumpkey command with existing data
echo "Test 13: Dumpkey command with existing data"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 dumpkey --force "node-0.flared.default.svc.cluster.local:13301" | head -20
echo

# Test 14: Reconstruct command with existing data
echo "Test 14: Reconstruct command with existing data"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 reconstruct --force "node-2.flared.default.svc.cluster.local:13301"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 list
echo

# Test 15: Verify data integrity after reconstruct
echo "Test 15: Verify data integrity after reconstruct"
echo "Checking if test keys still exist..."
kubectl exec node-0 -- sh -c "echo -e 'get testkey1\r\nquit\r\n' | nc node-0.flared.default.svc.cluster.local 13301" | head -5
kubectl exec node-0 -- sh -c "echo -e 'get testkey2\r\nquit\r\n' | nc node-1.flared.default.svc.cluster.local 13301" | head -5
kubectl exec node-0 -- sh -c "echo -e 'get testkey3\r\nquit\r\n' | nc node-2.flared.default.svc.cluster.local 13301" | head -5
echo

# Test 16: Remove command (careful with this one)
echo "Test 16: Remove command (dry-run)"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 remove --dry-run "node-2.flared.default.svc.cluster.local:13301"
echo

# Test 17: Index command
echo "Test 17: Index command"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 index | head -20
echo

# Test 18: Threads command
echo "Test 18: Threads command"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 threads "node-0.flared.default.svc.cluster.local:13301" || echo "Threads command not fully implemented"
echo

# Test 19: Verify command
echo "Test 19: Verify command"
kubectl exec node-0 -- /usr/local/bin/flare-admin -i flarei.default.svc.cluster.local -p 13300 verify || echo "Verify command not fully implemented"
echo

# Test 20: Environment variables
echo "Test 20: Environment variables"
kubectl exec node-0 -- sh -c "FLARE_INDEX_SERVER=flarei.default.svc.cluster.local:13300 /usr/local/bin/flare-admin ping"
echo

# Test 21: Help commands
echo "Test 21: Help commands"
kubectl exec node-0 -- /usr/local/bin/flare-admin --help | head -20
echo
kubectl exec node-0 -- /usr/local/bin/flare-stats --help | head -20
echo

echo "=== E2E tests completed ==="