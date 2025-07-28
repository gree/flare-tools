package admin

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/gree/flare-tools/internal/config"
)

// MockFlareServer provides a simple mock flare server for testing
type MockFlareServer struct {
	listener  net.Listener
	port      int
	dataPort  int    // Port for data node connections
	nodeState string // Track node state for reconstruction simulation
}

func (m *MockFlareServer) Start() error {
	var err error
	m.listener, err = net.Listen("tcp", ":0")
	if err != nil {
		return err
	}

	m.port = m.listener.Addr().(*net.TCPAddr).Port

	go func() {
		for {
			conn, err := m.listener.Accept()
			if err != nil {
				return
			}
			go m.handleConnection(conn)
		}
	}()

	return nil
}

func (m *MockFlareServer) StartDataNode() error {
	// Start a second listener for data node connections
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		return err
	}

	m.dataPort = listener.Addr().(*net.TCPAddr).Port

	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go m.handleDataNodeConnection(conn)
		}
	}()

	return nil
}

func (m *MockFlareServer) Stop() {
	if m.listener != nil {
		m.listener.Close()
	}
}

func (m *MockFlareServer) Port() int {
	return m.port
}

func (m *MockFlareServer) DataPort() int {
	return m.dataPort
}

func (m *MockFlareServer) handleConnection(conn net.Conn) {
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		command := strings.TrimSpace(scanner.Text())
		response := m.processCommand(command)
		conn.Write([]byte(response))
	}
}

func (m *MockFlareServer) handleDataNodeConnection(conn net.Conn) {
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		command := strings.TrimSpace(scanner.Text())
		response := m.processDataNodeCommand(command)
		conn.Write([]byte(response))
	}
}

func (m *MockFlareServer) processCommand(command string) string {
	parts := strings.Fields(command)
	if len(parts) == 0 {
		return "ERROR invalid command\r\n"
	}

	cmd := strings.ToLower(parts[0])

	switch cmd {
	case "ping":
		return "OK\r\n"
	case "flush_all":
		return "OK\r\n"
	case "stats":
		// Return stats in the correct format showing the node is ready
		// Use localhost address so tests can connect to the data node
		return fmt.Sprintf("STAT 127.0.0.1:%d:role master\r\nSTAT 127.0.0.1:%d:state %s\r\nSTAT 127.0.0.1:%d:partition 0\r\nSTAT 127.0.0.1:%d:balance 1\r\nEND\r\n", m.dataPort, m.dataPort, m.nodeState, m.dataPort, m.dataPort)
	case "threads":
		return "thread_pool_size=16\r\nactive_threads=8\r\nqueue_size=0\r\nEND\r\n"
	case "node":
		// Handle node commands (add, role, state, etc.)
		if len(parts) >= 2 {
			subCmd := strings.ToLower(parts[1])
			switch subCmd {
			case "add", "balance":
				return "OK\r\n"
			case "role":
				// Handle role changes: node role hostname port newrole balance partition
				if len(parts) >= 6 {
					newRole := parts[4]
					// After setting role to slave, immediately transition to active state
					if newRole == "slave" {
						m.nodeState = "active"
					}
				}
				return "OK\r\n"
			case "state":
				// Handle state changes: node state hostname port newstate
				if len(parts) >= 5 {
					newState := parts[4]
					m.nodeState = newState
					// For reconstruction: after setting to "down", the role command will set it to active
				}
				return "OK\r\n"
			default:
				return "OK\r\n"
			}
		}
		return "OK\r\n"
	case "quit":
		return ""
	default:
		return "ERROR unknown command\r\n"
	}
}

func (m *MockFlareServer) processDataNodeCommand(command string) string {
	parts := strings.Fields(command)
	if len(parts) == 0 {
		return "ERROR invalid command\r\n"
	}

	cmd := strings.ToLower(parts[0])

	switch cmd {
	case "ping":
		return "OK\r\n"
	case "flush_all":
		return "OK\r\n"
	case "stats":
		return fmt.Sprintf("STAT 127.0.0.1:%d:role master\r\nSTAT 127.0.0.1:%d:state ready\r\nSTAT 127.0.0.1:%d:partition 0\r\nSTAT 127.0.0.1:%d:balance 1\r\nEND\r\n", m.dataPort, m.dataPort, m.dataPort, m.dataPort)
	case "threads":
		return "thread_pool_size=16\r\nactive_threads=8\r\nqueue_size=0\r\nEND\r\n"
	case "dump":
		return "VALUE key1 0 6 1 0\r\nvalue1\r\nVALUE key2 0 6 1 0\r\nvalue2\r\nEND\r\n"
	case "dump_all":
		return "dumped 100 keys\r\nEND\r\n"
	case "dump_key":
		return "KEY key1\r\nKEY key2\r\nEND\r\n"
	case "set":
		// Handle set command for restore functionality
		if len(parts) >= 5 {
			return "STORED\r\n"
		}
		return "ERROR invalid set command\r\n"
	case "quit":
		return ""
	default:
		// Check if it's a multiline set command
		if strings.Contains(command, "\r\n") && strings.HasPrefix(command, "set ") {
			return "STORED\r\n"
		}
		return "OK\r\n"
	}
}

func startMockServer(t *testing.T) *MockFlareServer {
	server := &MockFlareServer{
		nodeState: "ready", // Initial state
	}
	err := server.Start()
	if err != nil {
		t.Fatalf("Failed to start mock server: %v", err)
	}

	// Also start the data node
	err = server.StartDataNode()
	if err != nil {
		t.Fatalf("Failed to start mock data node: %v", err)
	}

	// Give the server a moment to start
	time.Sleep(10 * time.Millisecond)

	t.Cleanup(func() {
		server.Stop()
	})

	return server
}

func TestNewCLI(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	assert.NotNil(t, cli)
	assert.Equal(t, cfg, cli.config)
}

func TestGetCommands(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	commands := cli.GetCommands()

	assert.Len(t, commands, 16)

	expectedCommands := []string{
		"ping", "stats", "list", "master", "slave", "balance", "down",
		"reconstruct", "remove", "dump", "dumpkey", "restore", "activate",
		"index", "threads", "verify",
	}

	for i, cmd := range commands {
		assert.Equal(t, expectedCommands[i], cmd.Use[:len(expectedCommands[i])])
	}
}

func TestRunMasterWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runMaster([]string{}, false, false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "master command requires at least one hostname:port:balance:partition argument")
}

func TestRunMasterWithForce(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.Force = true
	cfg.DryRun = true // Use dry run to avoid complex master construction
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	// Use withoutClean=true to skip the flush_all step that requires connecting to the data node
	err := cli.runMaster([]string{"server1:12121:1:0"}, false, true)
	assert.NoError(t, err)
}

func TestRunSlaveWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runSlave([]string{}, false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "slave command requires at least one hostname:port:balance:partition argument")
}

func TestRunSlaveWithForce(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.Force = true
	cfg.DryRun = true // Use dry run to avoid complex slave construction
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	// Use withoutClean=true to skip the flush_all step that requires connecting to the data node
	err := cli.runSlave([]string{"server1:12121:1:0"}, true)
	assert.NoError(t, err)
}

func TestRunBalanceWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runBalance([]string{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "balance command requires at least one hostname:port:balance argument")
}

func TestRunBalanceWithForce(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.Force = true
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runBalance([]string{"server1:12121:2"})
	assert.NoError(t, err)
}

func TestRunDownWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runDown([]string{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "down command requires at least one hostname:port argument")
}

func TestRunDownWithForce(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.Force = true
	cfg.DryRun = true // Use dry run to avoid actual state changes
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runDown([]string{"server1:12121"})
	assert.NoError(t, err)
}

func TestRunReconstructWithoutArgsOrAll(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runReconstruct([]string{}, false, false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "reconstruct command requires at least one hostname:port argument or --all flag")
}

func TestRunReconstructWithAll(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.Force = true
	cfg.DryRun = true // Use dry run to avoid complex state management
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runReconstruct([]string{}, false, true)
	assert.NoError(t, err)
}

func TestRunRemoveWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runRemove([]string{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "remove command requires at least one hostname:port argument")
}

func TestRunRemoveWithForce(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.Force = true
	cfg.DryRun = true // Use dry run to avoid complex state validation
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runRemove([]string{"server1:12121"})
	assert.NoError(t, err)
}

func TestRunDumpWithoutArgsOrAll(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runDump([]string{}, "", "default", false, false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "dump command requires at least one hostname:port argument or --all flag")
}

func TestRunDumpWithAll(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.DryRun = true // Use dry run to avoid connecting to data nodes
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runDump([]string{}, "", "default", true, false)
	assert.NoError(t, err)
}

func TestRunDumpkeyWithoutArgsOrAll(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runDumpkey([]string{}, "", "csv", -1, 0, false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "dumpkey command requires at least one hostname:port argument or --all flag")
}

func TestRunDumpkeyWithAll(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.DryRun = true // Use dry run to avoid connecting to data nodes
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runDumpkey([]string{}, "", "csv", -1, 0, true)
	assert.NoError(t, err)
}

func TestRunRestoreWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runRestore([]string{}, "", "tch", "", "", "", false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "restore command requires at least one hostname:port argument")
}

func TestRunRestoreWithoutInput(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runRestore([]string{"server1:12121"}, "", "tch", "", "", "", false)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "restore command requires --input parameter")
}

func TestRunRestoreWithInput(t *testing.T) {
	// Create temp file for test
	tmpDir, err := os.MkdirTemp("", "restore-test-*")
	require.NoError(t, err)
	defer os.RemoveAll(tmpDir)
	
	dumpFile := filepath.Join(tmpDir, "backup.tch")
	err = os.WriteFile(dumpFile, []byte("VALUE test 0 4 1 0\ndata\nEND\n"), 0644)
	require.NoError(t, err)
	
	cfg := config.NewConfig()
	cfg.DryRun = true // Use dry run to avoid actual restore operations
	cli := NewCLI(cfg)

	err = cli.runRestore([]string{"server1:12121"}, dumpFile, "tch", "", "", "", false)
	assert.NoError(t, err)
}

func TestRunActivateWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runActivate([]string{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "activate command requires at least one hostname:port argument")
}

func TestRunActivateWithForce(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.Force = true
	cfg.DryRun = true // Use dry run to avoid actual state changes
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runActivate([]string{"server1:12121"})
	assert.NoError(t, err)
}

func TestRunIndex(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	err := cli.runIndex("", 0)
	assert.NoError(t, err)
}

func TestRunThreadsWithoutArgs(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runThreads([]string{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "threads command requires at least one hostname:port argument")
}

func TestRunThreadsWithArgs(t *testing.T) {
	server := startMockServer(t)

	cfg := config.NewConfig()
	cfg.IndexServer = "127.0.0.1"
	cfg.IndexServerPort = server.Port()
	cli := NewCLI(cfg)

	// Use the mock data node address
	err := cli.runThreads([]string{fmt.Sprintf("127.0.0.1:%d", server.DataPort())})
	assert.NoError(t, err)
}

func TestRunVerify(t *testing.T) {
	// For now, just test that the verify function exists and can be called
	// TODO: Implement full verification testing with proper mock setup
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	// Test that the function exists and accepts the correct parameters
	// We expect this to fail due to connection error, but that's OK for now
	err := cli.runVerify("", false, false, false, false, false, true) // quiet=true to reduce output
	assert.Error(t, err)                                              // We expect an error since there's no real server
	assert.Contains(t, err.Error(), "cluster verification failed")
}
