package e2e

import (
	"bufio"
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type MockFlareServer struct {
	listener net.Listener
	port     int
	responses map[string]string
}

func NewMockFlareServer() (*MockFlareServer, error) {
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		return nil, err
	}
	
	port := listener.Addr().(*net.TCPAddr).Port
	
	// Use localhost instead of server1/server2 for testability
	server := &MockFlareServer{
		listener: listener,
		port:     port,
		responses: map[string]string{
			"ping": "OK\r\n",
			"stats nodes": fmt.Sprintf("STAT 127.0.0.1:%d:role master\r\nSTAT 127.0.0.1:%d:state active\r\nSTAT 127.0.0.1:%d:partition 0\r\nSTAT 127.0.0.1:%d:balance 1\r\nSTAT 127.0.0.1:%d:thread_type 16\r\nEND\r\n", port, port, port, port, port),
			"node role 127.0.0.1 " + fmt.Sprintf("%d", port) + " master 1 0": "STORED\r\n",
			"node state 127.0.0.1 " + fmt.Sprintf("%d", port) + " down": "STORED\r\n",
			"node state 127.0.0.1 " + fmt.Sprintf("%d", port) + " active": "STORED\r\n",
			"flush_all": "OK\r\n",
			// Data operations for testing dump/dumpkey/reconstruct
			"set testkey1 0 0 10": "STORED\r\n",
			"set testkey2 0 0 10": "STORED\r\n", 
			"set testkey3 0 0 10": "STORED\r\n",
			"get testkey1": "VALUE testkey1 0 10\r\ntestvalue1\r\nEND\r\n",
			"get testkey2": "VALUE testkey2 0 10\r\ntestvalue2\r\nEND\r\n",
			"get testkey3": "VALUE testkey3 0 10\r\ntestvalue3\r\nEND\r\n",
			// Dump responses (simulate keys with data)
			"dump": "testkey1 testvalue1\r\ntestkey2 testvalue2\r\ntestkey3 testvalue3\r\nEND\r\n",
			"dump_key": "KEY testkey1\r\nKEY testkey2\r\nKEY testkey3\r\nEND\r\n",
		},
	}
	
	go server.serve()
	
	return server, nil
}

func (s *MockFlareServer) serve() {
	for {
		conn, err := s.listener.Accept()
		if err != nil {
			return
		}
		
		go s.handleConnection(conn)
	}
}

func (s *MockFlareServer) handleConnection(conn net.Conn) {
	defer conn.Close()
	
	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		command := strings.TrimSpace(scanner.Text())
		
		if response, exists := s.responses[command]; exists {
			conn.Write([]byte(response))
		} else {
			conn.Write([]byte("ERROR unknown command\r\nEND\r\n"))
		}
	}
}

func (s *MockFlareServer) Close() error {
	return s.listener.Close()
}

func (s *MockFlareServer) Port() int {
	return s.port
}

func buildBinaries(t *testing.T) (string, string) {
	projectRoot, err := filepath.Abs("../..")
	require.NoError(t, err)
	
	tmpDir := t.TempDir()
	
	flareAdminPath := filepath.Join(tmpDir, "flare-admin")
	flareStatsPath := filepath.Join(tmpDir, "flare-stats")
	
	cmd := exec.Command("go", "build", "-o", flareAdminPath, "./cmd/flare-admin")
	cmd.Dir = projectRoot
	err = cmd.Run()
	require.NoError(t, err, "Failed to build flare-admin")
	
	cmd = exec.Command("go", "build", "-o", flareStatsPath, "./cmd/flare-stats")
	cmd.Dir = projectRoot
	err = cmd.Run()
	require.NoError(t, err, "Failed to build flare-stats")
	
	return flareAdminPath, flareStatsPath
}

func TestFlareStatsE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	_, flareStatsPath := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareStatsPath,
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "hostname:port")
	assert.Contains(t, outputStr, "server1:12121")
	assert.Contains(t, outputStr, "server2:12121")
	assert.Contains(t, outputStr, "active")
	assert.Contains(t, outputStr, "master")
	assert.Contains(t, outputStr, "slave")
}

func TestFlareStatsWithQPSE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	_, flareStatsPath := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareStatsPath,
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--qps",
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "qps")
	assert.Contains(t, outputStr, "qps-r")
	assert.Contains(t, outputStr, "qps-w")
}

func TestFlareAdminPingE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "ping",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "alive")
}

func TestFlareAdminStatsE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "stats",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "hostname:port")
	assert.Contains(t, outputStr, "server1:12121")
	assert.Contains(t, outputStr, "server2:12121")
}

func TestFlareAdminListE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "list",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "node")
	assert.Contains(t, outputStr, "partition")
	assert.Contains(t, outputStr, "role")
	assert.Contains(t, outputStr, "state")
	assert.Contains(t, outputStr, "balance")
}

func TestFlareAdminMasterWithForceE2E(t *testing.T) {
	t.Skip("Skipping test that requires real flare data nodes for flush_all")
}

func TestFlareAdminSlaveWithForceE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "slave",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--force",
		"server2:12121:1:0",
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	// Slave command should execute without error when using force flag
	// The actual output might vary based on node state
	_ = string(output) // Output logged if needed
}

func TestFlareAdminBalanceWithForceE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "balance",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--force",
		"server1:12121:2",
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Setting balance values")
	assert.Contains(t, outputStr, "Operation completed successfully")
}

func TestFlareAdminDownWithForceE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "down",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--force",
		"server1:12121",
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Turning down nodes")
	assert.Contains(t, outputStr, "Operation completed successfully")
}

func TestFlareAdminReconstructWithForceE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "reconstruct",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--force",
		"server1:12121",
	)
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("Reconstruct command failed with output: %s", output)
	}
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Reconstructing nodes")
}

func TestFlareAdminEnvironmentVariables(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "ping")
	cmd.Env = append(os.Environ(),
		fmt.Sprintf("FLARE_INDEX_SERVER=127.0.0.1:%d", mockServer.Port()),
	)
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("Ping command with env failed with output: %s", output)
	}
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "alive")
}

func TestFlareAdminHelpE2E(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "--help")
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Flare-admin is a command line tool")
	assert.Contains(t, outputStr, "Available Commands:")
	assert.Contains(t, outputStr, "ping")
	assert.Contains(t, outputStr, "stats")
	assert.Contains(t, outputStr, "list")
	assert.Contains(t, outputStr, "master")
	assert.Contains(t, outputStr, "slave")
}

func TestFlareStatsHelpE2E(t *testing.T) {
	_, flareStatsPath := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareStatsPath, "--help")
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Flare-stats is a command line tool")
	assert.Contains(t, outputStr, "--index-server")
	assert.Contains(t, outputStr, "--qps")
	assert.Contains(t, outputStr, "--count")
}

func TestFlareAdminErrorHandling(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareAdminPath, "master")
	
	output, err := cmd.CombinedOutput()
	assert.Error(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "master command requires at least one hostname:port:balance:partition argument")
}

func TestFlareStatsConnectionError(t *testing.T) {
	_, flareStatsPath := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, flareStatsPath,
		"--index-server", "127.0.0.1",
		"--index-server-port", "99999",
	)
	
	output, err := cmd.CombinedOutput()
	assert.Error(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "failed")
}

func TestFlareAdminDumpWithDataE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// Create temp file for dump output
	tmpFile := filepath.Join(t.TempDir(), "test_dump.txt")
	
	// Test dump command with existing data
	cmd := exec.CommandContext(ctx, flareAdminPath, "dump",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--output", tmpFile,
		"--dry-run",
		fmt.Sprintf("127.0.0.1:%d", mockServer.Port()),
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Dumping data")
}

func TestFlareAdminDumpkeyWithDataE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// Create temp file for dumpkey output
	tmpFile := filepath.Join(t.TempDir(), "test_dumpkey.txt")
	
	// Test dumpkey command with existing data
	cmd := exec.CommandContext(ctx, flareAdminPath, "dumpkey",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--output", tmpFile,
		"--dry-run",
		fmt.Sprintf("127.0.0.1:%d", mockServer.Port()),
	)
	
	output, err := cmd.Output()
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Dumping keys")
}

func TestFlareAdminReconstructWithDataE2E(t *testing.T) {
	mockServer, err := NewMockFlareServer()
	require.NoError(t, err)
	defer mockServer.Close()
	
	flareAdminPath, _ := buildBinaries(t)
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// Test reconstruct command with existing data (should preserve data)
	cmd := exec.CommandContext(ctx, flareAdminPath, "reconstruct",
		"--index-server", "127.0.0.1",
		"--index-server-port", fmt.Sprintf("%d", mockServer.Port()),
		"--force",
		"--dry-run",
		fmt.Sprintf("127.0.0.1:%d", mockServer.Port()),
	)
	
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("Reconstruct command with data failed with output: %s", output)
	}
	require.NoError(t, err)
	
	outputStr := string(output)
	assert.Contains(t, outputStr, "Reconstructing nodes")
}