package integration

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/gree/flare-tools/internal/admin"
	"github.com/gree/flare-tools/internal/config"
	"github.com/gree/flare-tools/internal/flare"
	"github.com/gree/flare-tools/internal/stats"
)

func TestConfigIntegration(t *testing.T) {
	cfg := config.NewConfig()

	assert.NotNil(t, cfg)
	assert.Equal(t, "127.0.0.1", cfg.IndexServer)
	assert.Equal(t, 12120, cfg.IndexServerPort)

	address := cfg.GetIndexServerAddress()
	assert.Equal(t, "127.0.0.1:12120", address)
}

func TestFlareClientIntegration(t *testing.T) {
	cfg := config.NewConfig()
	client := flare.NewClient(cfg.IndexServer, cfg.IndexServerPort)

	assert.NotNil(t, client)
}

func TestStatsCLIIntegration(t *testing.T) {
	cfg := config.NewConfig()
	statsCli := stats.NewCLI(cfg)

	assert.NotNil(t, statsCli)
}

func TestAdminCLIIntegration(t *testing.T) {
	cfg := config.NewConfig()
	adminCli := admin.NewCLI(cfg)

	assert.NotNil(t, adminCli)

	commands := adminCli.GetCommands()
	assert.NotEmpty(t, commands)

	expectedCommands := []string{
		"ping", "stats", "list", "master", "slave", "balance", "down",
		"reconstruct", "remove", "dump", "dumpkey", "restore", "activate",
		"index", "threads", "verify",
	}

	assert.Len(t, commands, len(expectedCommands))
}

func TestConfigWithAdminCLI(t *testing.T) {
	cfg := config.NewConfig()
	cfg.Force = true
	cfg.Debug = true
	cfg.DryRun = true

	adminCli := admin.NewCLI(cfg)

	assert.NotNil(t, adminCli)

	commands := adminCli.GetCommands()
	assert.NotEmpty(t, commands)

	for _, cmd := range commands {
		assert.NotNil(t, cmd)
		assert.NotEmpty(t, cmd.Use)
		assert.NotEmpty(t, cmd.Short)
	}
}

func TestConfigWithStatsCLI(t *testing.T) {
	cfg := config.NewConfig()
	cfg.ShowQPS = true
	cfg.Wait = 5
	cfg.Count = 3
	cfg.Delimiter = ","

	statsCli := stats.NewCLI(cfg)

	assert.NotNil(t, statsCli)
}

func TestFullPipeline(t *testing.T) {
	cfg := config.NewConfig()
	cfg.IndexServer = "test.example.com"
	cfg.IndexServerPort = 12345
	cfg.ShowQPS = true
	cfg.Force = true

	client := flare.NewClient(cfg.IndexServer, cfg.IndexServerPort)
	assert.NotNil(t, client)

	statsCli := stats.NewCLI(cfg)
	assert.NotNil(t, statsCli)

	adminCli := admin.NewCLI(cfg)
	assert.NotNil(t, adminCli)

	commands := adminCli.GetCommands()
	assert.NotEmpty(t, commands)

	assert.Equal(t, "test.example.com:12345", cfg.GetIndexServerAddress())
}
