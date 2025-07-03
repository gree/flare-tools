package admin

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/gree/flare-tools/internal/flare"
	"github.com/spf13/cobra"
)

func (c *CLI) createPingCommand() *cobra.Command {
	var wait bool
	
	cmd := &cobra.Command{
		Use:   "ping [hostname:port] ...",
		Short: "Ping flare nodes",
		Long:  "Check if the specified nodes are alive by sending ping requests.",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				args = []string{c.config.GetIndexServerAddress()}
			}
			
			for _, arg := range args {
				parts := strings.Split(arg, ":")
				if len(parts) != 2 {
					return fmt.Errorf("invalid host:port format: %s", arg)
				}
				
				port, err := strconv.Atoi(parts[1])
				if err != nil {
					return fmt.Errorf("invalid port: %s", parts[1])
				}
				
				client := flare.NewClient(parts[0], port)
				if err := client.Ping(); err != nil {
					if wait {
						fmt.Printf("waiting for %s to respond...\n", arg)
						continue
					}
					return fmt.Errorf("ping failed for %s: %v", arg, err)
				}
				
				fmt.Printf("alive: %s\n", arg)
			}
			
			return nil
		},
	}
	
	cmd.Flags().BoolVar(&wait, "wait", false, "wait for OK responses from nodes")
	
	return cmd
}

func (c *CLI) createStatsCommand() *cobra.Command {
	var showQPS bool
	var wait int
	var count int
	var delimiter string
	
	cmd := &cobra.Command{
		Use:   "stats [hostname:port] ...",
		Short: "Show statistics of flare cluster",
		Long:  "Display status and statistics of nodes in a flare cluster.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.ShowQPS = showQPS
			c.config.Wait = wait
			c.config.Count = count
			c.config.Delimiter = delimiter
			
			client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
			return c.runStats(client)
		},
	}
	
	cmd.Flags().BoolVarP(&showQPS, "qps", "q", false, "show qps")
	cmd.Flags().IntVar(&wait, "wait", 0, "wait time for repeat (seconds)")
	cmd.Flags().IntVarP(&count, "count", "c", 1, "repeat count")
	cmd.Flags().StringVar(&delimiter, "delimiter", "\t", "delimiter")
	
	return cmd
}

func (c *CLI) createListCommand() *cobra.Command {
	var numericHosts bool
	
	cmd := &cobra.Command{
		Use:   "list",
		Short: "List nodes in flare cluster",
		Long:  "Show a list of nodes in the flare cluster.",
		RunE: func(cmd *cobra.Command, args []string) error {
			client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
			return c.runList(client, numericHosts)
		},
	}
	
	cmd.Flags().BoolVar(&numericHosts, "numeric-hosts", false, "show numerical host addresses")
	
	return cmd
}

func (c *CLI) createMasterCommand() *cobra.Command {
	var force bool
	var retry int
	var activate bool
	var withoutClean bool
	
	cmd := &cobra.Command{
		Use:   "master [hostname:port:balance:partition] ...",
		Short: "Construct partition with proxy node for master role",
		Long:  "Create a new partition in the cluster by promoting a proxy node to master.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.Force = force
			c.config.Retry = retry
			
			return c.runMaster(args, activate, withoutClean)
		},
	}
	
	cmd.Flags().BoolVar(&force, "force", false, "commit changes without confirmation")
	cmd.Flags().IntVar(&retry, "retry", 10, "retry count")
	cmd.Flags().BoolVar(&activate, "activate", false, "change node's state from ready to active")
	cmd.Flags().BoolVar(&withoutClean, "without-clean", false, "don't clear datastore before construction")
	
	return cmd
}

func (c *CLI) createSlaveCommand() *cobra.Command {
	var force bool
	var retry int
	var withoutClean bool
	
	cmd := &cobra.Command{
		Use:   "slave [hostname:port:balance:partition] ...",
		Short: "Construct slaves from proxy nodes",
		Long:  "Create slave nodes from proxy nodes in the cluster.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.Force = force
			c.config.Retry = retry
			
			return c.runSlave(args, withoutClean)
		},
	}
	
	cmd.Flags().BoolVar(&force, "force", false, "commit changes without confirmation")
	cmd.Flags().IntVar(&retry, "retry", 10, "retry count")
	cmd.Flags().BoolVar(&withoutClean, "without-clean", false, "don't clear datastore before construction")
	
	return cmd
}

func (c *CLI) createBalanceCommand() *cobra.Command {
	var force bool
	
	cmd := &cobra.Command{
		Use:   "balance [hostname:port:balance] ...",
		Short: "Set balance values of nodes",
		Long:  "Set the balance parameters of specified nodes.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.Force = force
			return c.runBalance(args)
		},
	}
	
	cmd.Flags().BoolVar(&force, "force", false, "commit changes without confirmation")
	
	return cmd
}

func (c *CLI) createDownCommand() *cobra.Command {
	var force bool
	
	cmd := &cobra.Command{
		Use:   "down [hostname:port] ...",
		Short: "Turn down nodes",
		Long:  "Turn down nodes and move them to proxy state.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.Force = force
			return c.runDown(args)
		},
	}
	
	cmd.Flags().BoolVar(&force, "force", false, "commit changes without confirmation")
	
	return cmd
}

func (c *CLI) createReconstructCommand() *cobra.Command {
	var force bool
	var unsafe bool
	var retry int
	var all bool
	
	cmd := &cobra.Command{
		Use:   "reconstruct [hostname:port] ...",
		Short: "Reconstruct database of nodes",
		Long:  "Reconstruct the database of nodes by copying from another node.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.Force = force
			c.config.Retry = retry
			
			return c.runReconstruct(args, unsafe, all)
		},
	}
	
	cmd.Flags().BoolVar(&force, "force", false, "commit changes without confirmation")
	cmd.Flags().BoolVar(&unsafe, "unsafe", false, "reconstruct node unsafely")
	cmd.Flags().IntVar(&retry, "retry", 10, "retry count")
	cmd.Flags().BoolVar(&all, "all", false, "reconstruct all nodes")
	
	return cmd
}

func (c *CLI) createRemoveCommand() *cobra.Command {
	var force bool
	var retry int
	
	cmd := &cobra.Command{
		Use:   "remove [hostname:port] ...",
		Short: "Remove nodes from cluster",
		Long:  "Remove specified nodes from the cluster.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.Force = force
			c.config.Retry = retry
			
			return c.runRemove(args)
		},
	}
	
	cmd.Flags().BoolVar(&force, "force", false, "commit changes without confirmation")
	cmd.Flags().IntVar(&retry, "retry", 0, "retry count")
	
	return cmd
}

func (c *CLI) createDumpCommand() *cobra.Command {
	var output string
	var format string
	var bwlimit int64
	var all bool
	var raw bool
	
	cmd := &cobra.Command{
		Use:   "dump [hostname:port] ...",
		Short: "Dump data from nodes",
		Long:  "Dump data from specified nodes to file.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.BandwidthLimit = bwlimit
			
			return c.runDump(args, output, format, all, raw)
		},
	}
	
	cmd.Flags().StringVarP(&output, "output", "o", "", "output to file")
	cmd.Flags().StringVarP(&format, "format", "f", "default", "output format [default,csv,tch]")
	cmd.Flags().Int64Var(&bwlimit, "bwlimit", 0, "bandwidth limit (bps)")
	cmd.Flags().BoolVar(&all, "all", false, "dump from all master nodes")
	cmd.Flags().BoolVar(&raw, "raw", false, "raw dump mode")
	
	return cmd
}

func (c *CLI) createDumpkeyCommand() *cobra.Command {
	var output string
	var format string
	var partition int
	var partitionSize int
	var bwlimit int64
	var all bool
	
	cmd := &cobra.Command{
		Use:   "dumpkey [hostname:port] ...",
		Short: "Dump keys from nodes",
		Long:  "Dump keys from specified nodes.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.BandwidthLimit = bwlimit
			
			return c.runDumpkey(args, output, format, partition, partitionSize, all)
		},
	}
	
	cmd.Flags().StringVarP(&output, "output", "o", "", "output to file")
	cmd.Flags().StringVarP(&format, "format", "f", "csv", "output format")
	cmd.Flags().IntVar(&partition, "partition", -1, "partition number")
	cmd.Flags().IntVarP(&partitionSize, "partition-size", "s", 0, "partition size")
	cmd.Flags().Int64Var(&bwlimit, "bwlimit", 0, "bandwidth limit (bps)")
	cmd.Flags().BoolVar(&all, "all", false, "dump from all partitions")
	
	return cmd
}

func (c *CLI) createRestoreCommand() *cobra.Command {
	var input string
	var format string
	var bwlimit int64
	var include string
	var prefixInclude string
	var exclude string
	var printKeys bool
	
	cmd := &cobra.Command{
		Use:   "restore [hostname:port]",
		Short: "Restore data to nodes",
		Long:  "Restore data to specified nodes from file.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.BandwidthLimit = bwlimit
			
			return c.runRestore(args, input, format, include, prefixInclude, exclude, printKeys)
		},
	}
	
	cmd.Flags().StringVar(&input, "input", "", "input from file")
	cmd.Flags().StringVarP(&format, "format", "f", "tch", "input format")
	cmd.Flags().Int64Var(&bwlimit, "bwlimit", 0, "bandwidth limit (bps)")
	cmd.Flags().StringVar(&include, "include", "", "include pattern")
	cmd.Flags().StringVar(&prefixInclude, "prefix-include", "", "prefix string")
	cmd.Flags().StringVar(&exclude, "exclude", "", "exclude pattern")
	cmd.Flags().BoolVar(&printKeys, "print-keys", false, "enable key dump to console")
	
	return cmd
}

func (c *CLI) createActivateCommand() *cobra.Command {
	var force bool
	
	cmd := &cobra.Command{
		Use:   "activate [hostname:port] ...",
		Short: "Activate nodes",
		Long:  "Activate specified nodes in the cluster.",
		RunE: func(cmd *cobra.Command, args []string) error {
			c.config.Force = force
			return c.runActivate(args)
		},
	}
	
	cmd.Flags().BoolVar(&force, "force", false, "commit changes without confirmation")
	
	return cmd
}

func (c *CLI) createIndexCommand() *cobra.Command {
	var output string
	var increment int
	
	cmd := &cobra.Command{
		Use:   "index",
		Short: "Print index XML document",
		Long:  "Generate and print the index XML document from cluster information.",
		RunE: func(cmd *cobra.Command, args []string) error {
			return c.runIndex(output, increment)
		},
	}
	
	cmd.Flags().StringVar(&output, "output", "", "output index to file")
	cmd.Flags().IntVar(&increment, "increment", 0, "increment node_map_version")
	
	return cmd
}

func (c *CLI) createThreadsCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "threads [hostname:port]",
		Short: "Show thread status",
		Long:  "Show the thread status of specified node.",
		RunE: func(cmd *cobra.Command, args []string) error {
			return c.runThreads(args)
		},
	}
	
	return cmd
}

func (c *CLI) createVerifyCommand() *cobra.Command {
	var keyHashAlgorithm string
	var useTestData bool
	var debug bool
	var bit64 bool
	var verbose bool
	var meta bool
	var quiet bool
	
	cmd := &cobra.Command{
		Use:   "verify",
		Short: "Verify cluster",
		Long:  "Verify the cluster configuration and data integrity.",
		RunE: func(cmd *cobra.Command, args []string) error {
			return c.runVerify(keyHashAlgorithm, useTestData, debug, bit64, verbose, meta, quiet)
		},
	}
	
	cmd.Flags().StringVar(&keyHashAlgorithm, "key-hash-algorithm", "", "key hash algorithm")
	cmd.Flags().BoolVar(&useTestData, "use-test-data", false, "store test data")
	cmd.Flags().BoolVar(&debug, "debug", false, "use debug mode")
	cmd.Flags().BoolVar(&bit64, "64bit", false, "64bit mode")
	cmd.Flags().BoolVar(&verbose, "verbose", false, "use verbose mode")
	cmd.Flags().BoolVar(&meta, "meta", false, "use meta command")
	cmd.Flags().BoolVar(&quiet, "quiet", false, "use quiet mode")
	
	return cmd
}