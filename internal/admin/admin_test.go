package admin

import (
	"testing"

	"github.com/gree/flare-tools/internal/config"
	"github.com/stretchr/testify/assert"
)

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
	cfg := config.NewConfig()
	cfg.Force = true
	cli := NewCLI(cfg)
	
	err := cli.runMaster([]string{"server1:12121:1:0"}, false, false)
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
	cfg := config.NewConfig()
	cfg.Force = true
	cli := NewCLI(cfg)
	
	err := cli.runSlave([]string{"server1:12121:1:0"}, false)
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
	cfg := config.NewConfig()
	cfg.Force = true
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