package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/spf13/cobra"
)

var (
	namespace   string
	podSelector string
	container   string
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "kubectl-flare",
		Short: "kubectl plugin for flare-tools",
		Long: `kubectl-flare is a kubectl plugin that runs flare-tools commands on the index server.
It automatically finds the flare index server pod and executes flare-admin or flare-stats commands.`,
		Run: func(cmd *cobra.Command, args []string) {
			if len(args) == 0 {
				cmd.Help()
				os.Exit(0)
			}
			runFlareCommand(args)
		},
	}

	rootCmd.PersistentFlags().StringVarP(&namespace, "namespace", "n", "default", "Kubernetes namespace")
	rootCmd.PersistentFlags().StringVar(&podSelector, "pod-selector", "statefulset.kubernetes.io/pod-name=index-0", "Label selector to find index server pod")
	rootCmd.PersistentFlags().StringVar(&container, "container", "flarei", "Container name in the pod")

	// Add subcommands that mirror flare-admin commands
	adminCmd := &cobra.Command{
		Use:   "admin",
		Short: "Run flare-admin commands",
		Run: func(cmd *cobra.Command, args []string) {
			runFlareCommand(append([]string{"admin"}, args...))
		},
	}

	statsCmd := &cobra.Command{
		Use:   "stats",
		Short: "Run flare-stats commands",
		Run: func(cmd *cobra.Command, args []string) {
			runFlareCommand(append([]string{"stats"}, args...))
		},
	}

	rootCmd.AddCommand(adminCmd, statsCmd)

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runFlareCommand(args []string) {
	// Find the index server pod
	pod, err := findIndexServerPod()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error finding index server pod: %v\n", err)
		os.Exit(1)
	}

	// Determine which tool to run
	tool := "flare-admin"
	toolArgs := args
	if len(args) > 0 {
		switch args[0] {
		case "admin":
			tool = "flare-admin"
			toolArgs = args[1:]
		case "stats":
			tool = "flare-stats"
			toolArgs = args[1:]
		default:
			// Default to flare-admin for backward compatibility
			tool = "flare-admin"
			toolArgs = args
		}
	}

	// Build kubectl exec command
	kubectlArgs := []string{
		"exec",
		"-n", namespace,
		"-c", container,
		pod,
		"--",
		tool,
	}
	kubectlArgs = append(kubectlArgs, toolArgs...)

	// Execute kubectl exec
	cmd := exec.Command("kubectl", kubectlArgs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		fmt.Fprintf(os.Stderr, "Error executing command: %v\n", err)
		os.Exit(1)
	}
}

func findIndexServerPod() (string, error) {
	// Get pods matching the selector
	cmd := exec.Command("kubectl", "get", "pods", "-n", namespace, "-l", podSelector, "-o", "name", "--no-headers")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get pods: %w", err)
	}

	pods := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(pods) == 0 || pods[0] == "" {
		return "", fmt.Errorf("no pods found with selector %s", podSelector)
	}

	// Return the first pod name (remove "pod/" prefix)
	podName := strings.TrimPrefix(pods[0], "pod/")
	return podName, nil
}
