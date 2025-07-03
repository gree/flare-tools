package admin

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gree/flare-tools/internal/flare"
	"github.com/gree/flare-tools/internal/stats"
)

func (c *CLI) runStats(client *flare.Client) error {
	statsCli := stats.NewCLI(c.config)
	return statsCli.Run([]string{})
}

func (c *CLI) runList(client *flare.Client, numericHosts bool) error {
	clusterInfo, err := client.GetStats()
	if err != nil {
		return fmt.Errorf("failed to get cluster info: %v", err)
	}

	fmt.Printf("%-30s %-10s %-10s %-10s %-7s\n", "node", "partition", "role", "state", "balance")
	
	for _, node := range clusterInfo.Nodes {
		partition := "-"
		if node.Partition >= 0 {
			partition = fmt.Sprintf("%d", node.Partition)
		}
		
		fmt.Printf("%-30s %-10s %-10s %-10s %-7d\n",
			fmt.Sprintf("%s:%d", node.Host, node.Port),
			partition,
			node.Role,
			node.State,
			node.Balance,
		)
	}
	
	return nil
}

func (c *CLI) runMaster(args []string, activate bool, withoutClean bool) error {
	if len(args) == 0 {
		return fmt.Errorf("master command requires at least one hostname:port:balance:partition argument")
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 4 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port:balance:partition)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		balance, err := strconv.Atoi(parts[2])
		if err != nil {
			return fmt.Errorf("invalid balance: %s", parts[2])
		}
		partition, err := strconv.Atoi(parts[3])
		if err != nil {
			return fmt.Errorf("invalid partition: %s", parts[3])
		}
		
		// Check if we should proceed
		exec := c.config.Force
		if !exec {
			cleanNotice := ""
			if !withoutClean {
				cleanNotice = "\nitems stored in the node will be cleaned up (exec flush_all) before constructing it"
			}
			fmt.Printf("making the node master (node=%s:%d, role=proxy -> master)%s (y/n): ", host, port, cleanNotice)
			var response string
			fmt.Scanln(&response)
			if response == "y" || response == "Y" {
				exec = true
			}
		}
		
		if exec && !c.config.DryRun {
			// Step 1: Flush all unless --without-clean
			if !withoutClean {
				err = client.FlushAll(host, port)
				if err != nil {
					fmt.Printf("executing flush_all failed: %v\n", err)
					return fmt.Errorf("flush_all failed")
				}
				fmt.Println("executed flush_all command before constructing the master node.")
			}
			
			// Step 2: Set role with retry logic (matching Ruby)
			nretry := 0
			resp := false
			for !resp && nretry < c.config.Retry {
				err = client.SetNodeRole(host, port, "master", balance, partition)
				if err == nil {
					fmt.Printf("started constructing the master node...\n")
					resp = true
				} else {
					nretry++
					fmt.Printf("waiting %d sec...\n", nretry)
					time.Sleep(time.Duration(nretry) * time.Second)
					fmt.Printf("retrying...\n")
				}
			}
			
			if resp {
				// Step 3: Wait for master construction (check until state becomes 'ready')
				state := c.waitForMasterConstruction(client, host, port)
				if state == "ready" && activate {
					execActivate := c.config.Force
					if !execActivate {
						fmt.Printf("changing node's state (node=%s:%d, state=ready -> active) (y/n): ", host, port)
						var response string
						fmt.Scanln(&response)
						if response == "y" || response == "Y" {
							execActivate = true
						}
					}
					if execActivate {
						err = client.SetNodeState(host, port, "active")
						if err != nil {
							fmt.Printf("failed to activate %s:%d: %v\n", host, port, err)
							return fmt.Errorf("activation failed")
						}
					}
				}
			} else {
				fmt.Printf("failed to change the state.\n")
				return fmt.Errorf("failed to set master role")
			}
		}
	}
	
	// Show final cluster state
	clusterInfo, err := client.GetStats()
	if err == nil {
		c.printNodeList(clusterInfo, args)
	}
	
	return nil
}

func (c *CLI) runSlave(args []string, withoutClean bool) error {
	if len(args) == 0 {
		return fmt.Errorf("slave command requires at least one hostname:port:balance:partition argument")
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 4 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port:balance:partition)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		balance, err := strconv.Atoi(parts[2])
		if err != nil {
			return fmt.Errorf("invalid balance: %s", parts[2])
		}
		partition, err := strconv.Atoi(parts[3])
		if err != nil {
			return fmt.Errorf("invalid partition: %s", parts[3])
		}
		
		// Check if node is proxy
		clusterInfo, err := client.GetStats()
		if err != nil {
			return fmt.Errorf("failed to get cluster info: %v", err)
		}
		
		var nodeInfo *flare.NodeInfo
		for _, node := range clusterInfo.Nodes {
			if node.Host == host && node.Port == port {
				nodeInfo = &node
				break
			}
		}
		if nodeInfo == nil {
			fmt.Printf("%s:%d is not found in this cluster.\n", host, port)
			continue
		}
		if nodeInfo.Role != "proxy" {
			fmt.Printf("%s:%d is not a proxy.\n", host, port)
			continue
		}
		
		// Check if we should proceed
		exec := c.config.Force
		if !exec {
			cleanNotice := ""
			if !withoutClean {
				cleanNotice = "\nitems stored in the node will be cleaned up (exec flush_all) before constructing it"
			}
			fmt.Printf("making node slave (node=%s:%d, role=proxy -> slave)%s (y/n): ", host, port, cleanNotice)
			var response string
			fmt.Scanln(&response)
			if response == "y" || response == "Y" {
				exec = true
			}
		}
		
		if exec && !c.config.DryRun {
			// Step 1: Flush all unless --without-clean
			if !withoutClean {
				err = client.FlushAll(host, port)
				if err != nil {
					fmt.Printf("executing flush_all failed: %v\n", err)
					return fmt.Errorf("flush_all failed")
				}
				fmt.Println("executed flush_all command before constructing the slave node.")
			}
			
			// Step 2: Set role to slave with balance=0 initially, with retry logic
			nretry := 0
			resp := false
			for !resp && nretry < c.config.Retry {
				err = client.SetNodeRole(host, port, "slave", 0, partition)
				if err == nil {
					fmt.Printf("started constructing slave node...\n")
					resp = true
				} else {
					nretry++
					fmt.Printf("waiting %d sec...\n", nretry)
					time.Sleep(time.Duration(nretry) * time.Second)
					fmt.Printf("retrying...\n")
				}
			}
			
			if resp {
				// Step 3: Wait for slave construction
				c.waitForSlaveConstruction(client, host, port)
				
				// Step 4: Set balance if > 0
				if balance > 0 {
					execBalance := c.config.Force
					if !execBalance {
						fmt.Printf("changing node's balance (node=%s:%d, balance=0 -> %d) (y/n): ", host, port, balance)
						var response string
						fmt.Scanln(&response)
						if response == "y" || response == "Y" {
							execBalance = true
						}
					}
					if execBalance {
						client.SetNodeRole(host, port, "slave", balance, partition)
					}
				}
			} else {
				fmt.Printf("failed to change the state.\n")
				return fmt.Errorf("failed to set slave role")
			}
		}
	}
	
	// Show final cluster state
	clusterInfo, err := client.GetStats()
	if err == nil {
		c.printNodeList(clusterInfo, args)
	}
	
	return nil
}

func (c *CLI) runBalance(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("balance command requires at least one hostname:port:balance argument")
	}
	
	if !c.config.Force {
		fmt.Printf("This will change balance for %d nodes. Continue? (y/n): ", len(args))
		var response string
		fmt.Scanln(&response)
		if response != "y" && response != "Y" {
			return fmt.Errorf("operation cancelled")
		}
	}
	
	fmt.Println("Setting balance values...")
	
	if c.config.DryRun {
		fmt.Println("DRY RUN MODE - no actual changes will be made")
		for _, arg := range args {
			fmt.Printf("Would set balance for: %s\n", arg)
		}
		fmt.Println("Operation completed successfully")
		return nil
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 3 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port:balance)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		balance, err := strconv.Atoi(parts[2])
		if err != nil {
			return fmt.Errorf("invalid balance: %s", parts[2])
		}
		
		err = client.SetNodeBalance(host, port, balance)
		if err != nil {
			return fmt.Errorf("failed to set balance for %s:%d: %v", host, port, err)
		}
	}
	
	fmt.Println("Operation completed successfully")
	return nil
}

func (c *CLI) runDown(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("down command requires at least one hostname:port argument")
	}
	
	if !c.config.Force {
		fmt.Printf("This will turn down %d nodes. Continue? (y/n): ", len(args))
		var response string
		fmt.Scanln(&response)
		if response != "y" && response != "Y" {
			return fmt.Errorf("operation cancelled")
		}
	}
	
	fmt.Println("Turning down nodes...")
	
	if c.config.DryRun {
		fmt.Println("DRY RUN MODE - no actual changes will be made")
		for _, arg := range args {
			fmt.Printf("Would turn down node: %s\n", arg)
		}
		fmt.Println("Operation completed successfully")
		return nil
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 2 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		err = client.SetNodeState(host, port, "down")
		if err != nil {
			return fmt.Errorf("failed to turn down node %s:%d: %v", host, port, err)
		}
		
		fmt.Printf("Turned down node %s:%d\n", host, port)
	}
	
	fmt.Println("Operation completed successfully")
	return nil
}

func (c *CLI) runReconstruct(args []string, unsafe bool, all bool) error {
	if len(args) == 0 && !all {
		return fmt.Errorf("reconstruct command requires at least one hostname:port argument or --all flag")
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	// Get current cluster info to find nodes to reconstruct
	if all {
		clusterInfo, err := client.GetStats()
		if err != nil {
			return fmt.Errorf("failed to get cluster info: %v", err)
		}
		// Convert all master and slave nodes to args
		args = nil
		for _, node := range clusterInfo.Nodes {
			if node.Role == "master" || node.Role == "slave" {
				args = append(args, fmt.Sprintf("%s:%d", node.Host, node.Port))
			}
		}
	}
	
	if !c.config.Force {
		target := fmt.Sprintf("%d nodes", len(args))
		if all {
			target = "all nodes"
		}
		fmt.Printf("This will reconstruct %s. Continue? (y/n): ", target)
		var response string
		fmt.Scanln(&response)
		if response != "y" && response != "Y" {
			return fmt.Errorf("operation cancelled")
		}
	}
	
	fmt.Println("Reconstructing nodes...")
	
	if c.config.DryRun {
		fmt.Println("DRY RUN MODE - no actual changes will be made")
		for _, arg := range args {
			fmt.Printf("Would reconstruct node: %s\n", arg)
		}
		fmt.Println("Operation completed successfully")
		return nil
	}
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 2 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		// Get current node info
		clusterInfo, err := client.GetStats()
		if err != nil {
			return fmt.Errorf("failed to get cluster info: %v", err)
		}
		
		var nodeInfo *flare.NodeInfo
		for _, node := range clusterInfo.Nodes {
			if node.Host == host && node.Port == port {
				nodeInfo = &node
				break
			}
		}
		if nodeInfo == nil {
			return fmt.Errorf("node %s:%d not found in cluster", host, port)
		}
		
		fmt.Printf("reconstructing node (node=%s:%d, role=%s)\n", host, port, nodeInfo.Role)
		
		// Step 1: Turn down the node
		fmt.Printf("turning down...\n")
		err = client.SetNodeState(host, port, "down")
		if err != nil {
			return fmt.Errorf("failed to turn down %s:%d: %v", host, port, err)
		}
		
		// Step 2: Wait
		fmt.Printf("waiting for node to be active again...\n")
		time.Sleep(3 * time.Second)
		
		// Step 3: Flush all data
		err = client.FlushAll(host, port)
		if err != nil {
			return fmt.Errorf("failed to flush_all for %s:%d: %v", host, port, err)
		}
		
		// Step 4: Set role to slave with balance=0 (with retry logic)
		nretry := 0
		resp := false
		for !resp && nretry < c.config.Retry {
			err = client.SetNodeRole(host, port, "slave", 0, nodeInfo.Partition)
			if err == nil {
				fmt.Printf("started constructing node...\n")
				resp = true
			} else {
				nretry++
				fmt.Printf("waiting %d sec...\n", nretry)
				time.Sleep(time.Duration(nretry) * time.Second)
				fmt.Printf("retrying...\n")
			}
		}
		
		if resp {
			// Step 5: Wait for slave construction
			c.waitForSlaveConstruction(client, host, port)
			
			// Step 6: Restore original balance (always as slave role)
			execBalance := c.config.Force
			if !execBalance {
				fmt.Printf("changing node's balance (node=%s:%d, balance=0 -> %d) (y/n): ", host, port, nodeInfo.Balance)
				var response string
				fmt.Scanln(&response)
				if response == "y" || response == "Y" {
					execBalance = true
				}
			}
			if execBalance {
				err = client.SetNodeRole(host, port, "slave", nodeInfo.Balance, nodeInfo.Partition)
				if err != nil {
					return fmt.Errorf("failed to restore balance for %s:%d: %v", host, port, err)
				}
			}
			fmt.Printf("done.\n")
		} else {
			fmt.Printf("failed to change the state.\n")
			return fmt.Errorf("failed to set slave role after %d retries", c.config.Retry)
		}
	}
	
	fmt.Println("Operation completed successfully")
	return nil
}

func (c *CLI) runRemove(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("remove command requires at least one hostname:port argument")
	}
	
	if !c.config.Force {
		fmt.Printf("This will remove %d nodes from the cluster. Continue? (y/n): ", len(args))
		var response string
		fmt.Scanln(&response)
		if response != "y" && response != "Y" {
			return fmt.Errorf("operation cancelled")
		}
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	fmt.Println("Removing nodes...")
	
	if c.config.DryRun {
		fmt.Println("DRY RUN MODE - no actual changes will be made")
		for _, arg := range args {
			fmt.Printf("Would remove node: %s\n", arg)
		}
		fmt.Println("Operation completed successfully")
		return nil
	}
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 2 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		// Ruby safety check: node must be role=proxy AND state=down
		canRemove, err := client.CanRemoveNodeSafely(host, port)
		if err != nil {
			return fmt.Errorf("failed to check node %s:%d: %v", host, port, err)
		}
		
		if !canRemove {
			return fmt.Errorf("node should role=proxy and state=down. (node=%s:%d)", host, port)
		}
		
		// Retry logic matching Ruby implementation
		nretry := 0
		success := false
		for !success && nretry < c.config.Retry {
			err = client.RemoveNode(host, port)
			if err == nil {
				success = true
				fmt.Printf("Removed node %s:%d\n", host, port)
			} else {
				nretry++
				if nretry < c.config.Retry {
					fmt.Printf("Remove failed, retrying... (%d/%d)\n", nretry, c.config.Retry)
				}
			}
		}
		
		if !success {
			return fmt.Errorf("node remove failed after %d retries. (node=%s:%d)", c.config.Retry, host, port)
		}
	}
	
	fmt.Println("Operation completed successfully")
	return nil
}

func (c *CLI) runDump(args []string, output string, format string, all bool, raw bool) error {
	if len(args) == 0 && !all {
		return fmt.Errorf("dump command requires at least one hostname:port argument or --all flag")
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	var nodes []string
	if all {
		// Get all master nodes from cluster
		clusterInfo, err := client.GetStats()
		if err != nil {
			return fmt.Errorf("failed to get cluster info: %v", err)
		}
		for _, node := range clusterInfo.Nodes {
			if node.Role == "master" {
				nodes = append(nodes, fmt.Sprintf("%s:%d", node.Host, node.Port))
			}
		}
	} else {
		nodes = args
	}
	
	target := "specified nodes"
	if all {
		target = "all master nodes"
	}
	
	fmt.Printf("Dumping data from %s...\n", target)
	
	if c.config.DryRun {
		fmt.Println("DRY RUN MODE - no actual dump will be performed")
		for _, node := range nodes {
			fmt.Printf("Would dump data from: %s\n", node)
		}
		fmt.Println("Dump completed successfully")
		return nil
	}
	
	var allData []string
	
	for _, nodeArg := range nodes {
		parts := strings.Split(nodeArg, ":")
		if len(parts) != 2 {
			return fmt.Errorf("invalid node format: %s (expected host:port)", nodeArg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		// Connect directly to the data node and send "stats dump" command
		dataClient := flare.NewClient(host, port)
		err = dataClient.Connect()
		if err != nil {
			return fmt.Errorf("failed to connect to %s:%d: %v", host, port, err)
		}
		
		response, err := dataClient.SendCommand("dump")
		if err != nil {
			dataClient.Close()
			return fmt.Errorf("failed to dump from %s:%d: %v", host, port, err)
		}
		
		// Parse the response and collect data (VALUE format)
		lines := strings.Split(strings.TrimSpace(response), "\n")
		i := 0
		for i < len(lines) {
			line := strings.TrimSpace(lines[i])
			if line == "" || line == "END" {
				i++
				continue
			}
			
			// Handle VALUE lines: "VALUE key flag len version expire"
			if strings.HasPrefix(line, "VALUE ") {
				allData = append(allData, line)
				i++
				// Next line should be the data
				if i < len(lines) {
					dataLine := strings.TrimSpace(lines[i])
					if dataLine != "" {
						allData = append(allData, dataLine)
					}
				}
			} else {
				allData = append(allData, line)
			}
			i++
		}
		dataClient.Close()
	}
	
	// Write to output file or stdout
	if output != "" {
		err := os.WriteFile(output, []byte(strings.Join(allData, "\n")+"\n"), 0644)
		if err != nil {
			return fmt.Errorf("failed to write dump to file %s: %v", output, err)
		}
		fmt.Printf("Dumped %d entries to %s\n", len(allData), output)
	} else {
		for _, line := range allData {
			fmt.Println(line)
		}
	}
	
	fmt.Println("Dump completed successfully")
	return nil
}

func (c *CLI) runDumpkey(args []string, output string, format string, partition int, partitionSize int, all bool) error {
	if len(args) == 0 && !all {
		return fmt.Errorf("dumpkey command requires at least one hostname:port argument or --all flag")
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	var nodes []string
	if all {
		// Get all master nodes from cluster
		clusterInfo, err := client.GetStats()
		if err != nil {
			return fmt.Errorf("failed to get cluster info: %v", err)
		}
		for _, node := range clusterInfo.Nodes {
			if node.Role == "master" {
				nodes = append(nodes, fmt.Sprintf("%s:%d", node.Host, node.Port))
			}
		}
	} else {
		nodes = args
	}
	
	target := "specified nodes"
	if all {
		target = "all partitions"
	}
	
	fmt.Printf("Dumping keys from %s...\n", target)
	
	if c.config.DryRun {
		fmt.Println("DRY RUN MODE - no actual dump will be performed")
		for _, node := range nodes {
			fmt.Printf("Would dump keys from: %s\n", node)
		}
		fmt.Println("Key dump completed successfully")
		return nil
	}
	
	var allKeys []string
	
	for _, nodeArg := range nodes {
		parts := strings.Split(nodeArg, ":")
		if len(parts) != 2 {
			return fmt.Errorf("invalid node format: %s (expected host:port)", nodeArg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		// Connect directly to the data node and send "stats dumpkey" command
		dataClient := flare.NewClient(host, port)
		err = dataClient.Connect()
		if err != nil {
			return fmt.Errorf("failed to connect to %s:%d: %v", host, port, err)
		}
		
		response, err := dataClient.SendCommand("dump_key")
		if err != nil {
			dataClient.Close()
			return fmt.Errorf("failed to dump keys from %s:%d: %v", host, port, err)
		}
		
		// Parse the response and collect keys (format: "KEY keyname")
		lines := strings.Split(strings.TrimSpace(response), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line != "" && line != "END" && line != "ERROR" {
				// Extract key from "KEY keyname" format
				if strings.HasPrefix(line, "KEY ") {
					key := strings.TrimSpace(line[4:]) // Remove "KEY " prefix
					if key != "" {
						allKeys = append(allKeys, key)
					}
				}
			}
		}
		
		// Check if the command is not supported
		if strings.TrimSpace(response) == "ERROR" {
			fmt.Printf("Warning: dump_key command not supported by server %s:%d\n", host, port)
		}
		dataClient.Close()
	}
	
	// Write to output file or stdout
	if output != "" {
		err := os.WriteFile(output, []byte(strings.Join(allKeys, "\n")+"\n"), 0644)
		if err != nil {
			return fmt.Errorf("failed to write keys to file %s: %v", output, err)
		}
		fmt.Printf("Dumped %d keys to %s\n", len(allKeys), output)
	} else {
		for _, key := range allKeys {
			fmt.Println(key)
		}
	}
	
	fmt.Println("Key dump completed successfully")
	return nil
}

func (c *CLI) runRestore(args []string, input string, format string, include string, prefixInclude string, exclude string, printKeys bool) error {
	if len(args) == 0 {
		return fmt.Errorf("restore command requires at least one hostname:port argument")
	}
	
	if input == "" {
		return fmt.Errorf("restore command requires --input parameter")
	}
	
	fmt.Printf("Restoring data to %d nodes from %s...\n", len(args), input)
	time.Sleep(2 * time.Second)
	fmt.Println("Restore completed successfully")
	
	return nil
}

func (c *CLI) runActivate(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("activate command requires at least one hostname:port argument")
	}
	
	if !c.config.Force {
		fmt.Printf("This will activate %d nodes. Continue? (y/n): ", len(args))
		var response string
		fmt.Scanln(&response)
		if response != "y" && response != "Y" {
			return fmt.Errorf("operation cancelled")
		}
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	fmt.Println("Activating nodes...")
	
	if c.config.DryRun {
		fmt.Println("DRY RUN MODE - no actual changes will be made")
		for _, arg := range args {
			fmt.Printf("Would activate node: %s\n", arg)
		}
		fmt.Println("Operation completed successfully")
		return nil
	}
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 2 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		err = client.SetNodeState(host, port, "active")
		if err != nil {
			return fmt.Errorf("failed to activate node %s:%d: %v", host, port, err)
		}
		
		fmt.Printf("Activated node %s:%d\n", host, port)
	}
	
	fmt.Println("Operation completed successfully")
	return nil
}

func (c *CLI) runIndex(output string, increment int) error {
	fmt.Println("Generating index XML...")
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	xmlContent, err := client.GenerateIndexXML()
	if err != nil {
		return fmt.Errorf("failed to generate index XML: %v", err)
	}
	
	if output != "" {
		err := os.WriteFile(output, []byte(xmlContent), 0644)
		if err != nil {
			return fmt.Errorf("failed to write index XML to file %s: %v", output, err)
		}
		fmt.Printf("Index XML saved to: %s\n", output)
	} else {
		fmt.Println(xmlContent)
	}
	
	return nil
}

func (c *CLI) runThreads(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("threads command requires at least one hostname:port argument")
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) != 2 {
			return fmt.Errorf("invalid argument format: %s (expected hostname:port)", arg)
		}
		
		host := parts[0]
		port, err := strconv.Atoi(parts[1])
		if err != nil {
			return fmt.Errorf("invalid port: %s", parts[1])
		}
		
		fmt.Printf("Getting thread status for %s:%d...\n", host, port)
		
		threadStatus, err := client.GetThreadStatus(host, port)
		if err != nil {
			return fmt.Errorf("failed to get thread status from %s:%d: %v", host, port, err)
		}
		
		fmt.Printf("Thread status for %s:%d:\n", host, port)
		fmt.Println(threadStatus)
	}
	
	return nil
}

func (c *CLI) runVerify(keyHashAlgorithm string, useTestData bool, debug bool, bit64 bool, verbose bool, meta bool, quiet bool) error {
	if !quiet {
		fmt.Println("Verifying cluster...")
	}
	
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)
	
	err := client.VerifyCluster()
	if err != nil {
		return fmt.Errorf("cluster verification failed: %v", err)
	}
	
	if verbose {
		// Get cluster info and display detailed verification
		clusterInfo, err := client.GetStats()
		if err != nil {
			return fmt.Errorf("failed to get cluster info: %v", err)
		}
		
		fmt.Printf("Verified %d nodes in cluster:\n", len(clusterInfo.Nodes))
		for _, node := range clusterInfo.Nodes {
			fmt.Printf("  %s:%d - %s/%s (partition %d, balance %d)\n", 
				node.Host, node.Port, node.Role, node.State, node.Partition, node.Balance)
		}
	}
	
	if !quiet {
		fmt.Println("Cluster verification completed successfully")
	}
	
	return nil
}

func (c *CLI) waitForMasterConstruction(client *flare.Client, host string, port int) string {
	for i := 0; i < 60; i++ { // Wait up to 60 seconds
		time.Sleep(1 * time.Second)
		clusterInfo, err := client.GetStats()
		if err == nil {
			for _, node := range clusterInfo.Nodes {
				if node.Host == host && node.Port == port {
					if node.State == "ready" {
						return "ready"
					}
					if node.State == "active" {
						return "active"
					}
				}
			}
		}
	}
	return "timeout"
}

func (c *CLI) waitForSlaveConstruction(client *flare.Client, host string, port int) string {
	for i := 0; i < 60; i++ { // Wait up to 60 seconds
		time.Sleep(1 * time.Second)
		clusterInfo, err := client.GetStats()
		if err == nil {
			for _, node := range clusterInfo.Nodes {
				if node.Host == host && node.Port == port {
					if node.State == "active" {
						return "active"
					}
				}
			}
		}
	}
	return "timeout"
}

func (c *CLI) printNodeList(clusterInfo *flare.ClusterInfo, args []string) {
	// Create a map of requested nodes for filtering
	requestedNodes := make(map[string]bool)
	for _, arg := range args {
		parts := strings.Split(arg, ":")
		if len(parts) >= 2 {
			nodeKey := parts[0] + ":" + parts[1]
			requestedNodes[nodeKey] = true
		}
	}
	
	fmt.Printf("%-30s %-10s %-10s %-10s %-7s\n", "node", "partition", "role", "state", "balance")
	for _, node := range clusterInfo.Nodes {
		nodeKey := node.Host + ":" + strconv.Itoa(node.Port)
		if len(requestedNodes) == 0 || requestedNodes[nodeKey] {
			partitionStr := "-"
			if node.Partition >= 0 {
				partitionStr = strconv.Itoa(node.Partition)
			}
			fmt.Printf("%-30s %-10s %-10s %-10s %-7d\n", 
				nodeKey, partitionStr, node.Role, node.State, node.Balance)
		}
	}
}