package stats

import (
	"fmt"
	"strings"
	"time"

	"github.com/gree/flare-tools/internal/config"
	"github.com/gree/flare-tools/internal/flare"
)

type CLI struct {
	config *config.Config
}

func NewCLI(cfg *config.Config) *CLI {
	return &CLI{config: cfg}
}

func (c *CLI) Run(args []string) error {
	client := flare.NewClient(c.config.IndexServer, c.config.IndexServerPort)

	for i := 0; i < c.config.Count; i++ {
		if err := c.printStats(client); err != nil {
			return fmt.Errorf("failed to get stats: %v", err)
		}

		if i < c.config.Count-1 && c.config.Wait > 0 {
			time.Sleep(time.Duration(c.config.Wait) * time.Second)
		}
	}

	return nil
}

func (c *CLI) printStats(client *flare.Client) error {
	clusterInfo, err := client.GetStats()
	if err != nil {
		return err
	}

	c.printHeader()

	for _, node := range clusterInfo.Nodes {
		c.printNode(node)
	}

	return nil
}

func (c *CLI) printHeader() {
	headers := []string{
		"hostname:port",
		"state",
		"role",
		"partition",
		"balance",
		"items",
		"conn",
		"behind",
		"hit",
		"size",
		"uptime",
		"version",
	}

	if c.config.ShowQPS {
		headers = append(headers, "qps", "qps-r", "qps-w")
	}

	fmt.Println(strings.Join(headers, c.config.Delimiter))
}

func (c *CLI) printNode(node flare.NodeInfo) {
	values := []string{
		fmt.Sprintf("%s:%d", node.Host, node.Port),
		node.State,
		node.Role,
		fmt.Sprintf("%d", node.Partition),
		fmt.Sprintf("%d", node.Balance),
		fmt.Sprintf("%d", node.Items),
		fmt.Sprintf("%d", node.Conn),
		fmt.Sprintf("%d", node.Behind),
		fmt.Sprintf("%.0f", node.Hit),
		fmt.Sprintf("%d", node.Size),
		node.Uptime,
		node.Version,
	}

	if c.config.ShowQPS {
		values = append(values,
			fmt.Sprintf("%.1f", node.QPS),
			fmt.Sprintf("%.1f", node.QPSR),
			fmt.Sprintf("%.1f", node.QPSW),
		)
	}

	fmt.Println(strings.Join(values, c.config.Delimiter))
}
