package stats

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/gree/flare-tools/internal/config"
)

func TestNewCLI(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	assert.NotNil(t, cli)
	assert.Equal(t, cfg, cli.config)
}

func TestPrintHeader(t *testing.T) {
	cfg := config.NewConfig()
	cli := NewCLI(cfg)

	cli.printHeader()
}

func TestPrintHeaderWithQPS(t *testing.T) {
	cfg := config.NewConfig()
	cfg.ShowQPS = true
	cli := NewCLI(cfg)

	cli.printHeader()
}
