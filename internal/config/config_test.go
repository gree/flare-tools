package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewConfig(t *testing.T) {
	cfg := NewConfig()

	assert.Equal(t, "127.0.0.1", cfg.IndexServer)
	assert.Equal(t, 12120, cfg.IndexServerPort)
	assert.False(t, cfg.Debug)
	assert.False(t, cfg.Warn)
	assert.False(t, cfg.DryRun)
	assert.Equal(t, "", cfg.LogFile)
	assert.False(t, cfg.ShowQPS)
	assert.Equal(t, 0, cfg.Wait)
	assert.Equal(t, 1, cfg.Count)
	assert.Equal(t, "\t", cfg.Delimiter)
	assert.False(t, cfg.Force)
	assert.Equal(t, 10, cfg.Retry)
	assert.Equal(t, int64(0), cfg.BandwidthLimit)
}

func TestNewConfigWithEnvironment(t *testing.T) {
	os.Setenv("FLARE_INDEX_SERVER", "test.example.com")
	os.Setenv("FLARE_INDEX_SERVER_PORT", "13130")
	defer func() {
		os.Unsetenv("FLARE_INDEX_SERVER")
		os.Unsetenv("FLARE_INDEX_SERVER_PORT")
	}()

	cfg := NewConfig()

	assert.Equal(t, "test.example.com", cfg.IndexServer)
	assert.Equal(t, 13130, cfg.IndexServerPort)
}

func TestNewConfigWithEnvironmentHostPort(t *testing.T) {
	os.Setenv("FLARE_INDEX_SERVER", "test.example.com:14140")
	defer func() {
		os.Unsetenv("FLARE_INDEX_SERVER")
	}()

	cfg := NewConfig()

	assert.Equal(t, "test.example.com", cfg.IndexServer)
	assert.Equal(t, 14140, cfg.IndexServerPort)
}

func TestGetIndexServerAddress(t *testing.T) {
	cfg := NewConfig()
	cfg.IndexServer = "test.example.com"
	cfg.IndexServerPort = 12345

	address := cfg.GetIndexServerAddress()
	assert.Equal(t, "test.example.com:12345", address)
}
