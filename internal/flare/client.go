package flare

import (
	"bufio"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"
)

type Client struct {
	host string
	port int
	conn net.Conn
}

type NodeInfo struct {
	Host      string
	Port      int
	Role      string
	State     string
	Partition int
	Balance   int
	Items     int64
	Conn      int
	Behind    int64
	Hit       float64
	Size      int64
	Uptime    string
	Version   string
	QPS       float64
	QPSR      float64
	QPSW      float64
}

type ClusterInfo struct {
	Nodes []NodeInfo
}

func NewClient(host string, port int) *Client {
	return &Client{
		host: host,
		port: port,
	}
}

func (c *Client) Connect() error {
	conn, err := net.DialTimeout("tcp", fmt.Sprintf("%s:%d", c.host, c.port), 10*time.Second)
	if err != nil {
		return fmt.Errorf("failed to connect to %s:%d: %v", c.host, c.port, err)
	}
	c.conn = conn
	return nil
}

func (c *Client) Close() error {
	if c.conn != nil {
		// Send quit command before closing, with timeout
		c.conn.SetDeadline(time.Now().Add(1 * time.Second))
		c.conn.Write([]byte("quit\r\n"))
		// Read any remaining response
		buf := make([]byte, 1024)
		c.conn.Read(buf)
		// Close the connection
		return c.conn.Close()
	}
	return nil
}

func (c *Client) SendCommand(cmd string) (string, error) {
	if c.conn == nil {
		return "", fmt.Errorf("not connected")
	}

	_, err := c.conn.Write([]byte(cmd + "\r\n"))
	if err != nil {
		return "", fmt.Errorf("failed to send command: %v", err)
	}

	scanner := bufio.NewScanner(c.conn)
	var response strings.Builder

	for scanner.Scan() {
		line := scanner.Text()
		response.WriteString(line)
		response.WriteString("\n")

		// Check for terminal responses that indicate command completion
		// For simple commands that return just OK
		if (cmd == "ping" || cmd == "flush_all") && line == "OK" {
			break
		}
		// For node commands that return OK or STORED
		if strings.HasPrefix(cmd, "node ") && (line == "OK" || line == "STORED") {
			break
		}
		// For set commands that return STORED
		if strings.HasPrefix(cmd, "set ") && line == "STORED" {
			break
		}
		// For stats commands that return END
		if line == "END" {
			break
		}
		// For error responses
		if line == "ERROR" || strings.HasPrefix(line, "SERVER_ERROR") || strings.HasPrefix(line, "CLIENT_ERROR") {
			break
		}
	}

	if err := scanner.Err(); err != nil {
		return "", fmt.Errorf("failed to read response: %v", err)
	}

	return response.String(), nil
}

func (c *Client) Ping() error {
	if err := c.Connect(); err != nil {
		return err
	}
	defer c.Close()

	_, err := c.SendCommand("ping")
	return err
}

func (c *Client) GetStats() (*ClusterInfo, error) {
	if err := c.Connect(); err != nil {
		return nil, err
	}
	defer c.Close()

	response, err := c.SendCommand("stats nodes")
	if err != nil {
		return nil, err
	}

	return c.parseStatsResponse(response)
}

func (c *Client) SetNodeRole(host string, port int, role string, balance int, partition int) error {
	if err := c.Connect(); err != nil {
		return err
	}
	defer c.Close()

	cmd := fmt.Sprintf("node role %s %d %s %d %d", host, port, role, balance, partition)
	response, err := c.SendCommand(cmd)
	if err != nil {
		return err
	}

	if !strings.Contains(response, "OK") && !strings.Contains(response, "STORED") {
		return fmt.Errorf("failed to set node role: %s", response)
	}

	return nil
}

func (c *Client) SetNodeState(host string, port int, state string) error {
	if err := c.Connect(); err != nil {
		return err
	}
	defer c.Close()

	cmd := fmt.Sprintf("node state %s %d %s", host, port, state)
	response, err := c.SendCommand(cmd)
	if err != nil {
		return err
	}

	if !strings.Contains(response, "OK") && !strings.Contains(response, "STORED") {
		return fmt.Errorf("failed to set node state: %s", response)
	}

	return nil
}

func (c *Client) RemoveNode(host string, port int) error {
	if err := c.Connect(); err != nil {
		return err
	}
	defer c.Close()

	cmd := fmt.Sprintf("node remove %s %d", host, port)
	response, err := c.SendCommand(cmd)
	if err != nil {
		return err
	}

	if !strings.Contains(response, "OK") && !strings.Contains(response, "STORED") {
		return fmt.Errorf("failed to remove node: %s", response)
	}

	return nil
}

func (c *Client) FlushAll(host string, port int) error {
	// Connect directly to the data node (not index server)
	dataClient := NewClient(host, port)
	if err := dataClient.Connect(); err != nil {
		return err
	}
	defer dataClient.Close()

	response, err := dataClient.SendCommand("flush_all")
	if err != nil {
		return err
	}

	if !strings.Contains(response, "OK") {
		return fmt.Errorf("flush_all failed: %s", response)
	}

	return nil
}

func (c *Client) parseStatsResponse(response string) (*ClusterInfo, error) {
	lines := strings.Split(response, "\n")
	nodeMap := make(map[string]*NodeInfo)

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || line == "END" || line == "ERROR" {
			continue
		}

		// Parse STAT lines: STAT node-0.flared.default.svc.cluster.local:13301:role proxy
		if !strings.HasPrefix(line, "STAT ") {
			continue
		}

		parts := strings.SplitN(line, " ", 2)
		if len(parts) != 2 {
			continue
		}

		// Split the key:value part
		keyValue := strings.SplitN(parts[1], " ", 2)
		if len(keyValue) != 2 {
			continue
		}

		key := keyValue[0]
		value := keyValue[1]

		// Extract node address and field name
		keyParts := strings.Split(key, ":")
		if len(keyParts) < 3 {
			continue
		}

		nodeAddr := strings.Join(keyParts[:2], ":") // host:port
		fieldName := keyParts[2]

		// Get or create node
		if nodeMap[nodeAddr] == nil {
			hostPort := strings.Split(nodeAddr, ":")
			if len(hostPort) != 2 {
				continue
			}
			port, err := strconv.Atoi(hostPort[1])
			if err != nil {
				continue
			}

			nodeMap[nodeAddr] = &NodeInfo{
				Host:      hostPort[0],
				Port:      port,
				Partition: -1, // Default for proxy nodes
			}
		}

		node := nodeMap[nodeAddr]

		// Set field values
		switch fieldName {
		case "role":
			node.Role = value
		case "state":
			node.State = value
		case "partition":
			if partition, err := strconv.Atoi(value); err == nil {
				node.Partition = partition
			}
		case "balance":
			if balance, err := strconv.Atoi(value); err == nil {
				node.Balance = balance
			}
		case "thread_type":
			// This seems to be a thread count or similar, we can use it for conn count
			if conn, err := strconv.Atoi(value); err == nil {
				node.Conn = conn
			}
		}
	}

	// Convert map to slice
	nodes := make([]NodeInfo, 0, len(nodeMap))
	for _, node := range nodeMap {
		// Set default values for missing fields
		if node.State == "" {
			node.State = "unknown"
		}
		if node.Role == "" {
			node.Role = "unknown"
		}
		if node.Uptime == "" {
			node.Uptime = "0s"
		}
		if node.Version == "" {
			node.Version = "1.3.4"
		}
		nodes = append(nodes, *node)
	}

	return &ClusterInfo{Nodes: nodes}, nil
}

// SetNodeBalance sets the balance value for a node.
func (c *Client) SetNodeBalance(host string, port int, balance int) error {
	cmd := fmt.Sprintf("node balance %s %d %d", host, port, balance)

	err := c.Connect()
	if err != nil {
		return err
	}
	defer c.Close()

	response, err := c.SendCommand(cmd)
	if err != nil {
		return err
	}

	if !strings.Contains(response, "OK") && !strings.Contains(response, "STORED") {
		return fmt.Errorf("set balance failed: %s", response)
	}

	return nil
}

// CanRemoveNodeSafely checks if a node can be safely removed (must be proxy and down).
func (c *Client) CanRemoveNodeSafely(host string, port int) (bool, error) {
	clusterInfo, err := c.GetStats()
	if err != nil {
		return false, fmt.Errorf("failed to get cluster info: %v", err)
	}

	for _, node := range clusterInfo.Nodes {
		if node.Host == host && node.Port == port {
			return node.Role == "proxy" && node.State == "down", nil
		}
	}

	return false, fmt.Errorf("node %s:%d not found in cluster", host, port)
}

// GetThreadStatus gets thread status for a node.
func (c *Client) GetThreadStatus(host string, port int) (string, error) {
	dataClient := NewClient(host, port)
	err := dataClient.Connect()
	if err != nil {
		return "", err
	}
	defer dataClient.Close()

	response, err := dataClient.SendCommand("stats threads")
	if err != nil {
		return "", err
	}

	return response, nil
}

// VerifyCluster performs cluster verification.
func (c *Client) VerifyCluster() error {
	err := c.Connect()
	if err != nil {
		return err
	}
	defer c.Close()

	// Get cluster info and verify each node
	clusterInfo, err := c.GetStats()
	if err != nil {
		return fmt.Errorf("failed to get cluster info: %v", err)
	}

	for _, node := range clusterInfo.Nodes {
		// Check if node is reachable
		nodeClient := NewClient(node.Host, node.Port)
		err := nodeClient.Connect()
		if err != nil {
			return fmt.Errorf("node %s:%d is not reachable: %v", node.Host, node.Port, err)
		}
		nodeClient.Close()
	}

	return nil
}

// GenerateIndexXML generates the cluster index XML.
func (c *Client) GenerateIndexXML() (string, error) {
	clusterInfo, err := c.GetStats()
	if err != nil {
		return "", fmt.Errorf("failed to get cluster info: %v", err)
	}

	var xml strings.Builder
	xml.WriteString(`<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<!DOCTYPE boost_serialization>
<boost_serialization signature="serialization::archive" version="4">
<node_map class_id='0' tracking_level='0' version='0'>
`)

	for i, node := range clusterInfo.Nodes {
		xml.WriteString(fmt.Sprintf(`  <item class_id='1' tracking_level='0' version='0'>
    <first>%d</first>
    <second class_id='2' tracking_level='1' version='0' object_id='_%d'>
      <node_server_name>%s</node_server_name>
      <node_server_port>%d</node_server_port>
      <node_role>%s</node_role>
      <node_state>%s</node_state>
      <node_partition>%d</node_partition>
      <node_balance>%d</node_balance>
    </second>
  </item>
`, node.Partition, i, node.Host, node.Port, node.Role, node.State, node.Partition, node.Balance))
	}

	xml.WriteString(`</node_map>
</boost_serialization>`)

	return xml.String(), nil
}

// Dump retrieves all key-value pairs from a node
func (c *Client) Dump(partition string) ([]string, error) {
	if err := c.Connect(); err != nil {
		return nil, err
	}
	defer c.Close()

	// Send dump command with optional partition
	cmd := "dump"
	if partition != "" {
		cmd = fmt.Sprintf("dump %s", partition)
	}

	_, err := c.conn.Write([]byte(cmd + "\r\n"))
	if err != nil {
		return nil, fmt.Errorf("failed to send dump command: %v", err)
	}

	scanner := bufio.NewScanner(c.conn)
	var result []string
	var currentValue []string

	for scanner.Scan() {
		line := scanner.Text()
		
		if line == "END" {
			break
		}

		if strings.HasPrefix(line, "VALUE ") {
			// If we have a previous VALUE, add it to results
			if len(currentValue) > 0 {
				result = append(result, currentValue...)
				currentValue = nil
			}
			// Start new VALUE
			currentValue = append(currentValue, line)
		} else if len(currentValue) > 0 {
			// This is data for the current VALUE
			currentValue = append(currentValue, line)
		}
	}

	// Add the last VALUE if any
	if len(currentValue) > 0 {
		result = append(result, currentValue...)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading dump response: %v", err)
	}

	return result, nil
}

// DumpKey retrieves all keys from a node
func (c *Client) DumpKey(partition string) ([]string, error) {
	if err := c.Connect(); err != nil {
		return nil, err
	}
	defer c.Close()

	// Send dump_key command with optional partition
	cmd := "dump_key"
	if partition != "" {
		cmd = fmt.Sprintf("dump_key %s", partition)
	}

	_, err := c.conn.Write([]byte(cmd + "\r\n"))
	if err != nil {
		return nil, fmt.Errorf("failed to send dump_key command: %v", err)
	}

	scanner := bufio.NewScanner(c.conn)
	var keys []string

	for scanner.Scan() {
		line := scanner.Text()
		
		if line == "END" {
			break
		}

		if strings.HasPrefix(line, "KEY ") {
			// Extract key from "KEY keyname"
			parts := strings.SplitN(line, " ", 2)
			if len(parts) == 2 {
				keys = append(keys, parts[1])
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading dump_key response: %v", err)
	}

	return keys, nil
}

// Set stores a key-value pair
func (c *Client) Set(key string, flags int, exptime int, data []byte) error {
	if err := c.Connect(); err != nil {
		return err
	}
	defer c.Close();

	// Send set command
	cmd := fmt.Sprintf("set %s %d %d %d", key, flags, exptime, len(data))
	_, err := c.conn.Write([]byte(cmd + "\r\n"))
	if err != nil {
		return fmt.Errorf("failed to send set command: %v", err)
	}

	// Send data
	_, err = c.conn.Write(data)
	if err != nil {
		return fmt.Errorf("failed to send data: %v", err)
	}

	// Send CRLF after data
	_, err = c.conn.Write([]byte("\r\n"))
	if err != nil {
		return fmt.Errorf("failed to send CRLF: %v", err)
	}

	// Read response
	scanner := bufio.NewScanner(c.conn)
	for scanner.Scan() {
		response := scanner.Text()
		if response == "STORED" {
			return nil
		}
		if strings.HasPrefix(response, "SERVER_ERROR") || strings.HasPrefix(response, "CLIENT_ERROR") || response == "ERROR" {
			return fmt.Errorf("unexpected response: %s", response)
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("failed to read response: %v", err)
	}

	return fmt.Errorf("no response from server")
}
