package flare

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewClient(t *testing.T) {
	client := NewClient("localhost", 12120)

	assert.Equal(t, "localhost", client.host)
	assert.Equal(t, 12120, client.port)
	assert.Nil(t, client.conn)
}

func TestParseStatsResponse(t *testing.T) {
	client := NewClient("localhost", 12120)

	response := `STAT server1:12121:role master
STAT server1:12121:state active
STAT server1:12121:partition 0
STAT server1:12121:balance 1
STAT server1:12121:thread_type 16
STAT server2:12121:role slave
STAT server2:12121:state active
STAT server2:12121:partition 0
STAT server2:12121:balance 1
STAT server2:12121:thread_type 17
END`

	clusterInfo, err := client.parseStatsResponse(response)

	assert.NoError(t, err)
	assert.Len(t, clusterInfo.Nodes, 2)

	// Find nodes by host (order may vary due to map iteration)
	var node1, node2 *NodeInfo
	for i := range clusterInfo.Nodes {
		if clusterInfo.Nodes[i].Host == "server1" {
			node1 = &clusterInfo.Nodes[i]
		} else if clusterInfo.Nodes[i].Host == "server2" {
			node2 = &clusterInfo.Nodes[i]
		}
	}

	assert.NotNil(t, node1)
	assert.Equal(t, "server1", node1.Host)
	assert.Equal(t, 12121, node1.Port)
	assert.Equal(t, "active", node1.State)
	assert.Equal(t, "master", node1.Role)
	assert.Equal(t, 0, node1.Partition)
	assert.Equal(t, 1, node1.Balance)
	assert.Equal(t, 16, node1.Conn)         // thread_type maps to conn
	assert.Equal(t, "1.3.4", node1.Version) // Default version

	assert.NotNil(t, node2)
	assert.Equal(t, "server2", node2.Host)
	assert.Equal(t, 12121, node2.Port)
	assert.Equal(t, "active", node2.State)
	assert.Equal(t, "slave", node2.Role)
	assert.Equal(t, 0, node2.Partition)
	assert.Equal(t, 1, node2.Balance)
	assert.Equal(t, 17, node2.Conn) // thread_type maps to conn
}

func TestParseStatsResponseWithInvalidData(t *testing.T) {
	client := NewClient("localhost", 12120)

	response := `invalid line
STAT invalid:format
STAT server1:invalid_port:role master
END`

	clusterInfo, err := client.parseStatsResponse(response)

	assert.NoError(t, err)
	assert.Len(t, clusterInfo.Nodes, 0)
}

func TestParseStatsResponseWithMinimalData(t *testing.T) {
	client := NewClient("localhost", 12120)

	response := `STAT server1:12121:role proxy
STAT server1:12121:state active
END`

	clusterInfo, err := client.parseStatsResponse(response)

	assert.NoError(t, err)
	assert.Len(t, clusterInfo.Nodes, 1)

	node := clusterInfo.Nodes[0]
	assert.Equal(t, "server1", node.Host)
	assert.Equal(t, 12121, node.Port)
	assert.Equal(t, "active", node.State)
	assert.Equal(t, "proxy", node.Role)
	assert.Equal(t, -1, node.Partition)    // Default for proxy
	assert.Equal(t, 0, node.Balance)       // Default
	assert.Equal(t, "1.3.4", node.Version) // Default
}
