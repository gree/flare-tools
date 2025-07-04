package admin

import (
	"bufio"
	"fmt"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"

	"github.com/gree/flare-tools/internal/config"
)

// MockFlareServer provides a simple mock flare server for testing
type MockFlareServer struct {
	listener net.Listener
	port     int
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

func (m *MockFlareServer) Stop() {
	if m.listener != nil {
		m.listener.Close()
	}
}

func (m *MockFlareServer) Port() int {
	return m.port
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
		return "STAT server1:12121:role master\r\nSTAT server1:12121:state ready\r\nSTAT server1:12121:partition 0\r\nSTAT server1:12121:balance 1\r\nEND\r\n"
	case "threads":
		return "thread_pool_size=16\r\nactive_threads=8\r\nqueue_size=0\r\nEND\r\n"
	case "node":
		// Handle node commands (add, role, state, etc.)
		if len(parts) >= 2 {
			subCmd := strings.ToLower(parts[1])
			switch subCmd {
			case "add", "role", "state", "balance":
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

func startMockServer(t *testing.T) *MockFlareServer {
	server := &MockFlareServer{}
	err := server.Start()
	if err != nil {
		t.Fatalf("Failed to start mock server: %v", err)
	}
	
	// Give the server a moment to start
	time.Sleep(10 * time.Millisecond)
	
	t.Cleanup(func() {
		server.Stop()
	})
	
	return server
}

func startMockDataNode(t *testing.T, port int) *MockFlareServer {
	server := &MockFlareServer{}
	var err error
	server.listener, err = net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		// If can't bind to specific port, skip the test
		t.Skipf("Cannot bind to port %d: %v", port, err)
	}
	
	server.port = port
	
	go func() {
		for {
			conn, err := server.listener.Accept()
			if err != nil {
				return
			}
			go server.handleConnection(conn)
		}
	}()
	
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
	cfg := config.NewConfig()
	cfg.Force = true
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
	cfg := config.NewConfig()
	cfg.Force = true
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
	cfg := config.NewConfig()
	cfg.Force = true
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
	cfg := config.NewConfig()
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
	cfg := config.NewConfig()
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
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runRestore([]string{"server1:12121"}, "backup.tch", "tch", "", "", "", false)
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
	cfg := config.NewConfig()
	cfg.Force = true
	cli := NewCLI(cfg)

	err := cli.runActivate([]string{"server1:12121"})
	assert.NoError(t, err)
}

func TestRunIndex(t *testing.T) {
	cfg := config.NewConfig()
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
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runThreads([]string{"server1:12121"})
	assert.NoError(t, err)
}

func TestRunVerify(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	err := cli.runVerify("", false, false, false, false, false, false)
	assert.NoError(t, err)
}
