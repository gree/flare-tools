package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"net"
	"strconv"
	"strings"
	"sync"
)

type NodeState string
type NodeRole string

const (
	StateActive NodeState = "active"
	StateDown   NodeState = "down"
	StateProxy  NodeState = "proxy"
	StateReady  NodeState = "ready"

	RoleMaster NodeRole = "master"
	RoleSlave  NodeRole = "slave"
	RoleProxy  NodeRole = "proxy"
)

type Node struct {
	Host      string
	Port      int
	Role      NodeRole
	State     NodeState
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

type MockFlareCluster struct {
	nodes map[string]*Node
	mutex sync.RWMutex
}

func NewMockFlareCluster() *MockFlareCluster {
	cluster := &MockFlareCluster{
		nodes: make(map[string]*Node),
	}

	cluster.initializeCluster()
	return cluster
}

func (c *MockFlareCluster) initializeCluster() {
	nodes := []*Node{
		{
			Host: "127.0.0.1", Port: 12121, Role: RoleMaster, State: StateActive,
			Partition: 0, Balance: 1, Items: 10000, Conn: 50, Behind: 0,
			Hit: 95.5, Size: 1024, Uptime: "2d", Version: "1.3.4",
			QPS: 150.5, QPSR: 80.2, QPSW: 70.3,
		},
		{
			Host: "127.0.0.1", Port: 12122, Role: RoleMaster, State: StateActive,
			Partition: 1, Balance: 1, Items: 10001, Conn: 55, Behind: 0,
			Hit: 94.8, Size: 1025, Uptime: "2d", Version: "1.3.4",
			QPS: 145.8, QPSR: 75.5, QPSW: 70.3,
		},
		{
			Host: "127.0.0.1", Port: 12123, Role: RoleSlave, State: StateActive,
			Partition: 0, Balance: 1, Items: 10000, Conn: 30, Behind: 5,
			Hit: 0.0, Size: 1024, Uptime: "2d", Version: "1.3.4",
			QPS: 80.2, QPSR: 80.2, QPSW: 0.0,
		},
		{
			Host: "127.0.0.1", Port: 12124, Role: RoleSlave, State: StateActive,
			Partition: 1, Balance: 1, Items: 10001, Conn: 32, Behind: 3,
			Hit: 0.0, Size: 1025, Uptime: "2d", Version: "1.3.4",
			QPS: 82.1, QPSR: 82.1, QPSW: 0.0,
		},
	}

	for _, node := range nodes {
		key := fmt.Sprintf("%s:%d", node.Host, node.Port)
		c.nodes[key] = node
	}
}

func (c *MockFlareCluster) handleConnection(conn net.Conn) {
	defer conn.Close()

	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		command := strings.TrimSpace(scanner.Text())
		log.Printf("Received command: %s", command)

		response := c.processCommand(command)
		conn.Write([]byte(response))
	}
}

func (c *MockFlareCluster) processCommand(command string) string {
	parts := strings.Fields(command)
	if len(parts) == 0 {
		return "ERROR invalid command\r\nEND\r\n"
	}

	cmd := strings.ToLower(parts[0])

	switch cmd {
	case "ping":
		return "OK\r\nEND\r\n"
	case "stats":
		return c.getStats()
	case "node_add":
		return c.handleNodeAdd(parts[1:])
	case "node_role":
		return c.handleNodeRole(parts[1:])
	case "node_state":
		return c.handleNodeState(parts[1:])
	case "node_remove":
		return c.handleNodeRemove(parts[1:])
	case "node_balance":
		return c.handleNodeBalance(parts[1:])
	case "threads":
		return c.getThreads()
	case "version":
		return "VERSION 1.3.4\r\nEND\r\n"
	default:
		return "ERROR unknown command\r\nEND\r\n"
	}
}

func (c *MockFlareCluster) getStats() string {
	c.mutex.RLock()
	defer c.mutex.RUnlock()

	var stats strings.Builder

	for _, node := range c.nodes {
		line := fmt.Sprintf("%s:%d %s %s %d %d %d %d %d %.1f %d %s %s %.1f %.1f %.1f\r\n",
			node.Host, node.Port, node.State, node.Role, node.Partition, node.Balance,
			node.Items, node.Conn, node.Behind, node.Hit, node.Size, node.Uptime,
			node.Version, node.QPS, node.QPSR, node.QPSW)
		stats.WriteString(line)
	}

	stats.WriteString("END\r\n")
	return stats.String()
}

func (c *MockFlareCluster) handleNodeAdd(args []string) string {
	if len(args) < 4 {
		return "ERROR insufficient arguments\r\nEND\r\n"
	}

	hostPort := args[0]
	role := args[1]
	partition, _ := strconv.Atoi(args[2])
	balance, _ := strconv.Atoi(args[3])

	parts := strings.Split(hostPort, ":")
	if len(parts) != 2 {
		return "ERROR invalid host:port format\r\nEND\r\n"
	}

	port, err := strconv.Atoi(parts[1])
	if err != nil {
		return "ERROR invalid port\r\nEND\r\n"
	}

	c.mutex.Lock()
	defer c.mutex.Unlock()

	node := &Node{
		Host: parts[0], Port: port, Role: NodeRole(role), State: StateReady,
		Partition: partition, Balance: balance, Items: 0, Conn: 0, Behind: 0,
		Hit: 0.0, Size: 0, Uptime: "0s", Version: "1.3.4",
		QPS: 0.0, QPSR: 0.0, QPSW: 0.0,
	}

	key := fmt.Sprintf("%s:%d", node.Host, node.Port)
	c.nodes[key] = node

	return "OK\r\nEND\r\n"
}

func (c *MockFlareCluster) handleNodeRole(args []string) string {
	if len(args) < 2 {
		return "ERROR insufficient arguments\r\nEND\r\n"
	}

	hostPort := args[0]
	role := args[1]

	c.mutex.Lock()
	defer c.mutex.Unlock()

	if node, exists := c.nodes[hostPort]; exists {
		node.Role = NodeRole(role)
		if role == "master" {
			node.State = StateActive
			node.Items = 10000
			node.QPS = 150.0
			node.QPSR = 75.0
			node.QPSW = 75.0
		} else if role == "slave" {
			node.State = StateActive
			node.Items = 10000
			node.QPS = 80.0
			node.QPSR = 80.0
			node.QPSW = 0.0
		}
		return "OK\r\nEND\r\n"
	}

	return "ERROR node not found\r\nEND\r\n"
}

func (c *MockFlareCluster) handleNodeState(args []string) string {
	if len(args) < 2 {
		return "ERROR insufficient arguments\r\nEND\r\n"
	}

	hostPort := args[0]
	state := args[1]

	c.mutex.Lock()
	defer c.mutex.Unlock()

	if node, exists := c.nodes[hostPort]; exists {
		node.State = NodeState(state)
		return "OK\r\nEND\r\n"
	}

	return "ERROR node not found\r\nEND\r\n"
}

func (c *MockFlareCluster) handleNodeRemove(args []string) string {
	if len(args) < 1 {
		return "ERROR insufficient arguments\r\nEND\r\n"
	}

	hostPort := args[0]

	c.mutex.Lock()
	defer c.mutex.Unlock()

	if _, exists := c.nodes[hostPort]; exists {
		delete(c.nodes, hostPort)
		return "OK\r\nEND\r\n"
	}

	return "ERROR node not found\r\nEND\r\n"
}

func (c *MockFlareCluster) handleNodeBalance(args []string) string {
	if len(args) < 2 {
		return "ERROR insufficient arguments\r\nEND\r\n"
	}

	hostPort := args[0]
	balance, err := strconv.Atoi(args[1])
	if err != nil {
		return "ERROR invalid balance value\r\nEND\r\n"
	}

	c.mutex.Lock()
	defer c.mutex.Unlock()

	if node, exists := c.nodes[hostPort]; exists {
		node.Balance = balance
		return "OK\r\nEND\r\n"
	}

	return "ERROR node not found\r\nEND\r\n"
}

func (c *MockFlareCluster) getThreads() string {
	return "thread_pool_size=16\r\nactive_threads=8\r\nqueue_size=0\r\nEND\r\n"
}

func main() {
	port := flag.Int("port", 12120, "Port to listen on")
	flag.Parse()

	cluster := NewMockFlareCluster()

	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		log.Fatal("Failed to listen:", err)
	}
	defer listener.Close()

	log.Printf("Mock Flare cluster listening on port %d", *port)
	log.Println("Initialized with 2 masters and 2 slaves:")
	for key, node := range cluster.nodes {
		log.Printf("  %s: %s %s (partition %d)", key, node.Role, node.State, node.Partition)
	}

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("Failed to accept connection: %v", err)
			continue
		}

		go cluster.handleConnection(conn)
	}
}
