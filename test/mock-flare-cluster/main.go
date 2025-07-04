package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"net"
	"strings"
	"sync"
)

type (
	NodeState string
	NodeRole  string
)

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
