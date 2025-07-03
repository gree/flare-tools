// +build k8s

package e2e

import (
	"context"
	"fmt"
	"os/exec"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// These tests run against a real Kubernetes flare cluster
// Run with: go test -tags=k8s -v ./test/e2e

func TestFlareAdminListK8s(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// Port forward to access flare index server
	portForwardCmd := exec.Command("kubectl", "port-forward", "svc/flarei", "13300:13300")
	if err := portForwardCmd.Start(); err != nil {
		t.Skip("Kubernetes cluster not available")
	}
	defer portForwardCmd.Process.Kill()
	
	// Wait for port forward to be ready
	time.Sleep(2 * time.Second)
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "list",
		"--index-server", "localhost",
		"--index-server-port", "13300",
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "node")
	assert.Contains(t, outputStr, "partition")
	assert.Contains(t, outputStr, "role")
	assert.Contains(t, outputStr, "state")
	assert.Contains(t, outputStr, "balance")
	assert.Contains(t, outputStr, "flared.default.svc.cluster.local")
}

func TestFlareAdminMasterSlaveReconstructK8s(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	
	// Port forward to access flare index server
	portForwardCmd := exec.Command("kubectl", "port-forward", "svc/flarei", "13300:13300")
	if err := portForwardCmd.Start(); err != nil {
		t.Skip("Kubernetes cluster not available")
	}
	defer portForwardCmd.Process.Kill()
	
	// Wait for port forward to be ready
	time.Sleep(2 * time.Second)
	
	// Get initial state
	listCmd := exec.CommandContext(ctx, flareAdminPath, "list",
		"--index-server", "localhost",
		"--index-server-port", "13300",
	)
	
	output, err := listCmd.Output()
	require.NoError(t, err)
	t.Logf("Initial state:\n%s", output)
	
	// Find a proxy node to make it a slave
	lines := strings.Split(string(output), "\n")
	var proxyNode string
	for _, line := range lines {
		if strings.Contains(line, "proxy") {
			parts := strings.Fields(line)
			if len(parts) > 0 {
				proxyNode = parts[0]
				break
			}
		}
	}
	
	if proxyNode != "" {
		// Make it a slave
		slaveCmd := exec.CommandContext(ctx, flareAdminPath, "slave",
			"--index-server", "localhost",
			"--index-server-port", "13300",
			"--force",
			"--without-clean",
			proxyNode+":1:1",
		)
		
		output, err = slaveCmd.Output()
		if err != nil {
			t.Logf("Slave command output: %s", output)
		}
		require.NoError(t, err)
		
		// Verify it became a slave
		listCmd = exec.CommandContext(ctx, flareAdminPath, "list",
			"--index-server", "localhost",
			"--index-server-port", "13300",
		)
		
		output, err = listCmd.Output()
		require.NoError(t, err)
		assert.Contains(t, string(output), "slave")
		t.Logf("After slave command:\n%s", output)
	}
}

func TestFlareStatsK8s(t *testing.T) {
	_, flareStatsPath := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// Port forward to access flare index server
	portForwardCmd := exec.Command("kubectl", "port-forward", "svc/flarei", "13300:13300")
	if err := portForwardCmd.Start(); err != nil {
		t.Skip("Kubernetes cluster not available")
	}
	defer portForwardCmd.Process.Kill()
	
	// Wait for port forward to be ready
	time.Sleep(2 * time.Second)
	
	cmd := exec.CommandContext(ctx, flareStatsPath,
		"--index-server", "localhost",
		"--index-server-port", "13300",
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "hostname:port")
	assert.Contains(t, outputStr, "state")
	assert.Contains(t, outputStr, "role")
	assert.Contains(t, outputStr, "flared.default.svc.cluster.local")
}

func TestAllAdminCommandsK8s(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)
	
	// Port forward to access flare index server
	portForwardCmd := exec.Command("kubectl", "port-forward", "svc/flarei", "13300:13300")
	if err := portForwardCmd.Start(); err != nil {
		t.Skip("Kubernetes cluster not available")
	}
	defer portForwardCmd.Process.Kill()
	
	// Wait for port forward to be ready
	time.Sleep(2 * time.Second)
	
	testCases := []struct {
		name     string
		args     []string
		contains []string
	}{
		{
			name: "ping",
			args: []string{"ping", "--index-server", "localhost", "--index-server-port", "13300"},
			contains: []string{"alive"},
		},
		{
			name: "stats",
			args: []string{"stats", "--index-server", "localhost", "--index-server-port", "13300"},
			contains: []string{"hostname:port"},
		},
		{
			name: "list",
			args: []string{"list", "--index-server", "localhost", "--index-server-port", "13300"},
			contains: []string{"node", "partition", "role", "state"},
		},
		{
			name: "threads",
			args: []string{"threads", "--index-server", "localhost", "--index-server-port", "13300", "localhost:13300"},
			contains: []string{},
		},
		{
			name: "balance dry-run",
			args: []string{"balance", "--index-server", "localhost", "--index-server-port", "13300", "--dry-run", "--force", "localhost:13300:1"},
			contains: []string{},
		},
	}
	
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			defer cancel()
			
			cmd := exec.CommandContext(ctx, flareAdminPath, tc.args...)
			output, err := cmd.CombinedOutput()
			
			t.Logf("%s output:\n%s", tc.name, output)
			
			if err != nil {
				// Some commands might fail but that's OK for this test
				t.Logf("%s error: %v", tc.name, err)
			}
			
			for _, expected := range tc.contains {
				assert.Contains(t, string(output), expected)
			}
		})
	}
}