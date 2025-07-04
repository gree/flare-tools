package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/gree/flare-tools/internal/config"
	"github.com/gree/flare-tools/internal/stats"
)

func main() {
	cfg := config.NewConfig()
	statsCli := stats.NewCLI(cfg)

	rootCmd := &cobra.Command{
		Use:   "flare-stats",
		Short: "Statistics tool for Flare cluster",
		Long:  "Flare-stats is a command line tool for acquiring statistics of flare nodes.",
		RunE: func(cmd *cobra.Command, args []string) error {
			return statsCli.Run(args)
		},
	}

	rootCmd.PersistentFlags().StringVarP(&cfg.IndexServer, "index-server", "i", "", "index server hostname")
	rootCmd.PersistentFlags().IntVarP(&cfg.IndexServerPort, "index-server-port", "p", 13300, "index server port")
	rootCmd.PersistentFlags().BoolVarP(&cfg.Debug, "debug", "d", false, "enable debug mode")
	rootCmd.PersistentFlags().BoolVarP(&cfg.Warn, "warn", "w", false, "turn on warnings")
	rootCmd.PersistentFlags().BoolVarP(&cfg.ShowQPS, "qps", "q", false, "show qps")
	rootCmd.PersistentFlags().IntVar(&cfg.Wait, "wait", 0, "wait time for repeat (seconds)")
	rootCmd.PersistentFlags().IntVarP(&cfg.Count, "count", "c", 1, "repeat count")
	rootCmd.PersistentFlags().StringVar(&cfg.Delimiter, "delimiter", "\t", "delimiter")

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
