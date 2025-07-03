package admin

import (
	"github.com/gree/flare-tools/internal/config"
	"github.com/spf13/cobra"
)

type CLI struct {
	config *config.Config
}

func NewCLI(cfg *config.Config) *CLI {
	return &CLI{config: cfg}
}

func (c *CLI) GetCommands() []*cobra.Command {
	return []*cobra.Command{
		c.createPingCommand(),
		c.createStatsCommand(),
		c.createListCommand(),
		c.createMasterCommand(),
		c.createSlaveCommand(),
		c.createBalanceCommand(),
		c.createDownCommand(),
		c.createReconstructCommand(),
		c.createRemoveCommand(),
		c.createDumpCommand(),
		c.createDumpkeyCommand(),
		c.createRestoreCommand(),
		c.createActivateCommand(),
		c.createIndexCommand(),
		c.createThreadsCommand(),
		c.createVerifyCommand(),
	}
}