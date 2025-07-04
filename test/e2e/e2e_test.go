package e2e

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var (
	flareIndexServer     = "localhost"
	flareIndexServerPort = "12120"
)

// setupDockerCluster starts the Docker flare cluster for testing
func setupDockerCluster(t *testing.T) {
	projectRoot, err := filepath.Abs("../..")
	require.NoError(t, err)

	// Check if Docker Compose is available
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "docker-compose", "--version")
	cmd.Dir = projectRoot
	err = cmd.Run()
	require.NoError(t, err, "docker-compose is required for e2e tests")

	// Start the Docker cluster
	ctx, cancel = context.WithTimeout(context.Background(), 180*time.Second)
	defer cancel()

	cmd = exec.CommandContext(ctx, "docker-compose", "up", "-d", "--build")
	cmd.Dir = projectRoot
	err = cmd.Run()
	require.NoError(t, err, "Failed to start Docker cluster")

	// Wait for services to be ready
	time.Sleep(15 * time.Second)

	// Verify the index server is responding
	for i := 0; i < 30; i++ {
		ctx, cancel = context.WithTimeout(context.Background(), 5*time.Second)
		cmd = exec.CommandContext(ctx, "docker", "exec", "flarei", "bash", "-c", "printf 'stats\\r\\nquit\\r\\n' | nc localhost 12120")
		err = cmd.Run()
		cancel()
		if err == nil {
			break
		}
		time.Sleep(2 * time.Second)
	}
	require.NoError(t, err, "Flare index server failed to start")

	// Cleanup function
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
		defer cancel()
		cmd := exec.CommandContext(ctx, "docker-compose", "down")
		cmd.Dir = projectRoot
		cmd.Run()
	})
}

func buildBinaries(t *testing.T) (string, string) {
	projectRoot, err := filepath.Abs("../..")
	require.NoError(t, err)

	tmpDir := t.TempDir()

	flareAdminPath := filepath.Join(tmpDir, "flare-admin")
	flareStatsPath := filepath.Join(tmpDir, "flare-stats")

	cmd := exec.Command("go", "build", "-o", flareAdminPath, "./cmd/flare-admin")
	cmd.Dir = projectRoot
	err = cmd.Run()
	require.NoError(t, err, "Failed to build flare-admin")

	cmd = exec.Command("go", "build", "-o", flareStatsPath, "./cmd/flare-stats")
	cmd.Dir = projectRoot
	err = cmd.Run()
	require.NoError(t, err, "Failed to build flare-stats")

	return flareAdminPath, flareStatsPath
}

func TestFlareStatsE2E(t *testing.T) {
	setupDockerCluster(t)
	_, flareStatsPath := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareStatsPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "hostname:port")
	// The Docker cluster has 4 nodes in proxy mode (no partitions assigned yet)
	assert.Contains(t, outputStr, "flared1:12121")
	assert.Contains(t, outputStr, "flared2:12122")
	assert.Contains(t, outputStr, "flared3:12123")
	assert.Contains(t, outputStr, "flared4:12124")
	assert.Contains(t, outputStr, "proxy")
	assert.Contains(t, outputStr, "active")
}

func TestFlareStatsWithQPSE2E(t *testing.T) {
	setupDockerCluster(t)
	_, flareStatsPath := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareStatsPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"--qps",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "hostname:port")
	assert.Contains(t, outputStr, "qps")
}

func TestFlareAdminPingE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"ping",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "alive")
}

func TestFlareAdminStatsE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"stats",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "hostname:port")
	// The Docker cluster has nodes with DNS names
	assert.Contains(t, outputStr, "flared1:12121")
	assert.Contains(t, outputStr, "flared2:12122")
}

func TestFlareAdminListE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"list",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "node")
	assert.Contains(t, outputStr, "partition")
	assert.Contains(t, outputStr, "role")
	assert.Contains(t, outputStr, "state")
}

func TestFlareAdminMasterWithForceE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"master",
		"--dry-run",
		"--force",
		"flared1:12121:1:0", // Use existing node for testing
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "flared1:12121")
}

func TestFlareAdminSlaveWithForceE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"slave",
		"--dry-run",
		"--force",
		"flared2:12122:1:0", // Use existing node for testing
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "flared2:12122")
}

func TestFlareAdminBalanceWithForceE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"balance",
		"--dry-run",
		"--force",
		"flared1:12121:2",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "flared1:12121")
}

func TestFlareAdminDownWithForceE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"down",
		"--dry-run",
		"--force",
		"flared3:12123", // Use existing node for testing
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "flared3:12123")
}

func TestFlareAdminReconstructWithForceE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"reconstruct",
		"--dry-run",
		"--force",
		"--all",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "Reconstructing")
}

func TestFlareAdminEnvironmentVariables(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareAdminPath, "ping")
	cmd.Env = append(os.Environ(),
		"FLARE_INDEX_SERVER="+flareIndexServer,
		"FLARE_INDEX_SERVER_PORT="+flareIndexServerPort,
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "OK")
}

func TestFlareAdminHelpE2E(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareAdminPath, "--help")

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "flare-admin")
	assert.Contains(t, outputStr, "Available Commands")
}

func TestFlareStatsHelpE2E(t *testing.T) {
	_, flareStatsPath := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, flareStatsPath, "--help")

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "flare-stats")
	assert.Contains(t, outputStr, "Usage")
}

func TestFlareAdminErrorHandling(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Test with invalid server
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", "127.0.0.1",
		"--index-server-port", "99999",
		"ping",
	)

	_, err := cmd.Output()
	require.Error(t, err) // Should fail to connect
}

func TestFlareStatsConnectionError(t *testing.T) {
	_, flareStatsPath := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Test with invalid server
	cmd := exec.CommandContext(ctx, flareStatsPath,
		"--index-server", "127.0.0.1",
		"--index-server-port", "99999",
	)

	_, err := cmd.Output()
	require.Error(t, err) // Should fail to connect
}

func TestFlareAdminDumpWithDataE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"--dry-run",
		"dump",
		"--all",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "DRY RUN MODE")
}

func TestFlareAdminDumpkeyWithDataE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"--dry-run",
		"dumpkey",
		"--all",
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "DRY RUN MODE")
}

func TestFlareAdminReconstructWithDataE2E(t *testing.T) {
	setupDockerCluster(t)
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Use dry-run to test command parsing without affecting cluster
	cmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"--dry-run",
		"--force",
		"reconstruct",
		"172.20.0.13:12123", // Use slave node for testing
	)

	output, err := cmd.Output()
	require.NoError(t, err)

	outputStr := string(output)
	assert.Contains(t, outputStr, "DRY RUN MODE")
}