package main

import (
	"fmt"
	"os"

	"github.com/gree/flare-tools/internal/admin"
	"github.com/gree/flare-tools/internal/config"
	"github.com/spf13/cobra"
)

func main() {
	cfg := config.NewConfig()
	adminCli := admin.NewCLI(cfg)
	
	rootCmd := &cobra.Command{
		Use:   "flare-admin",
		Short: "Management tool for Flare cluster",
		Long:  "Flare-admin is a command line tool for maintaining flare clusters.",
	}

	rootCmd.PersistentFlags().StringVarP(&cfg.IndexServer, "index-server", "i", "", "index server hostname")
	rootCmd.PersistentFlags().IntVarP(&cfg.IndexServerPort, "index-server-port", "p", 13300, "index server port")
	rootCmd.PersistentFlags().BoolVarP(&cfg.Debug, "debug", "d", false, "enable debug mode")
	rootCmd.PersistentFlags().BoolVarP(&cfg.Warn, "warn", "w", false, "turn on warnings")
	rootCmd.PersistentFlags().BoolVarP(&cfg.DryRun, "dry-run", "n", false, "dry run")
	rootCmd.PersistentFlags().StringVar(&cfg.LogFile, "log-file", "", "output log to file")

	rootCmd.AddCommand(adminCli.GetCommands()...)

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}