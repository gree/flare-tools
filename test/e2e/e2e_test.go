package e2e

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var (
	flareIndexServer     = "localhost"
	flareIndexServerPort = "12120"
	projectRoot          string
)

// TestMain sets up the Docker cluster once for all tests
func TestMain(m *testing.M) {
	var err error
	projectRoot, err = filepath.Abs("../..")
	if err != nil {
		panic(err)
	}

	// Check if Docker Compose is available
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "docker-compose", "--version")
	cmd.Dir = projectRoot
	err = cmd.Run()
	if err != nil {
		panic("docker-compose is required for e2e tests")
	}

	// Start the Docker cluster
	ctx, cancel = context.WithTimeout(context.Background(), 180*time.Second)
	defer cancel()

	cmd = exec.CommandContext(ctx, "docker-compose", "up", "-d", "--build")
	cmd.Dir = projectRoot
	err = cmd.Run()
	if err != nil {
		panic("Failed to start Docker cluster")
	}

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
	if err != nil {
		panic("Flare index server failed to start")
	}

	// Run tests
	code := m.Run()

	// Cleanup
	ctx, cancel = context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	cmd = exec.CommandContext(ctx, "docker-compose", "down")
	cmd.Dir = projectRoot
	cmd.Run()

	os.Exit(code)
}


func buildBinaries(t *testing.T) (string, string) {
	tmpDir := t.TempDir()

	flareAdminPath := filepath.Join(tmpDir, "flare-admin")
	flareStatsPath := filepath.Join(tmpDir, "flare-stats")

	cmd := exec.Command("go", "build", "-o", flareAdminPath, "./cmd/flare-admin")
	cmd.Dir = projectRoot
	err := cmd.Run()
	require.NoError(t, err, "Failed to build flare-admin")

	cmd = exec.Command("go", "build", "-o", flareStatsPath, "./cmd/flare-stats")
	cmd.Dir = projectRoot
	err = cmd.Run()
	require.NoError(t, err, "Failed to build flare-stats")

	return flareAdminPath, flareStatsPath
}

func TestFlareStatsE2E(t *testing.T) {
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

func TestFlareAdminDumpRestoreE2E(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Create temp directory for dump files
	tmpDir, err := os.MkdirTemp("", "dump-restore-e2e-*")
	require.NoError(t, err)
	defer os.RemoveAll(tmpDir)

	dumpFile := filepath.Join(tmpDir, "cluster_dump.txt")

	// Step 1: Add some test data to the cluster using netcat
	addTestDataCmd := exec.CommandContext(ctx, "bash", "-c", `echo -e "set testkey1 0 0 10\r\ntestvalue1\r\nset testkey2 0 0 10\r\ntestvalue2\r\nset testkey3 0 0 15\r\nlongtestvalue3\r\nquit\r\n" | nc localhost 12121`)
	err = addTestDataCmd.Run()
	require.NoError(t, err, "Failed to add test data")

	// Wait for data to be distributed
	time.Sleep(2 * time.Second)

	// Step 2: Dump data from master nodes
	dumpCmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"dump",
		"--all",
		"--output", dumpFile,
	)

	output, err := dumpCmd.Output()
	require.NoError(t, err, "Dump command failed: %s", string(output))

	// Verify dump file was created and contains data
	dumpData, err := os.ReadFile(dumpFile)
	require.NoError(t, err)
	dumpStr := string(dumpData)
	
	// Should contain our test keys
	assert.Contains(t, dumpStr, "testkey1", "Dump should contain testkey1")
	assert.Contains(t, dumpStr, "testkey2", "Dump should contain testkey2")
	assert.Contains(t, dumpStr, "testkey3", "Dump should contain testkey3")
	assert.Contains(t, dumpStr, "testvalue1", "Dump should contain testvalue1")
	assert.Contains(t, dumpStr, "testvalue2", "Dump should contain testvalue2")
	assert.Contains(t, dumpStr, "longtestvalue3", "Dump should contain longtestvalue3")

	// Count the number of VALUE lines to verify we have data
	valueLines := strings.Count(dumpStr, "VALUE ")
	assert.Greater(t, valueLines, 0, "Dump should contain at least one VALUE line")

	// Step 3: Clear data from one node to test restore
	clearCmd := exec.CommandContext(ctx, "bash", "-c", `echo -e "flush_all\r\nquit\r\n" | nc localhost 12122`)
	err = clearCmd.Run()
	require.NoError(t, err, "Failed to clear data from target node")

	time.Sleep(1 * time.Second)

	// Step 4: Restore data to the cleared node
	restoreCmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"restore",
		"--input", dumpFile,
		"--print-keys",
		"localhost:12122",
	)

	restoreOutput, err := restoreCmd.Output()
	require.NoError(t, err, "Restore command failed: %s", string(restoreOutput))

	restoreStr := string(restoreOutput)
	
	// Verify restore output
	assert.Contains(t, restoreStr, "Restored key: testkey1", "Should restore testkey1")
	assert.Contains(t, restoreStr, "Restored key: testkey2", "Should restore testkey2")
	assert.Contains(t, restoreStr, "Restored key: testkey3", "Should restore testkey3")
	assert.Contains(t, restoreStr, "Restore completed successfully", "Should complete successfully")

	// Step 5: Verify data was actually restored by checking if we can retrieve it
	verifyCmd := exec.CommandContext(ctx, "bash", "-c", `echo -e "get testkey1\r\nget testkey2\r\nget testkey3\r\nquit\r\n" | nc localhost 12122`)
	verifyOutput, err := verifyCmd.Output()
	require.NoError(t, err, "Failed to verify restored data")

	verifyStr := string(verifyOutput)
	assert.Contains(t, verifyStr, "testvalue1", "Should be able to retrieve testvalue1")
	assert.Contains(t, verifyStr, "testvalue2", "Should be able to retrieve testvalue2")
	assert.Contains(t, verifyStr, "longtestvalue3", "Should be able to retrieve longtestvalue3")

	t.Logf("Successfully dumped %d items and restored them", valueLines)
}

func TestFlareAdminRestoreWithFiltersE2E(t *testing.T) {
	flareAdminPath, _ := buildBinaries(t)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Create temp directory for dump files
	tmpDir, err := os.MkdirTemp("", "restore-filter-e2e-*")
	require.NoError(t, err)
	defer os.RemoveAll(tmpDir)

	dumpFile := filepath.Join(tmpDir, "filter_test_dump.txt")

	// Step 1: Create test dump file with various keys
	testDump := `VALUE user:1 0 5 1 0
data1
VALUE user:2 0 5 1 0
data2
VALUE session:abc 0 5 1 0
data3
VALUE config:main 0 5 1 0
data4
VALUE temp:xyz 0 5 1 0
data5
END`

	err = os.WriteFile(dumpFile, []byte(testDump), 0644)
	require.NoError(t, err)

	// Step 2: Test restore with include filter (only restore user keys)
	restoreCmd := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"restore",
		"--input", dumpFile,
		"--include", "user",
		"--print-keys",
		"localhost:12123",
	)

	restoreOutput, err := restoreCmd.Output()
	require.NoError(t, err, "Restore with include filter failed: %s", string(restoreOutput))

	restoreStr := string(restoreOutput)
	
	// Should only restore user keys
	assert.Contains(t, restoreStr, "Restored key: user:1", "Should restore user:1")
	assert.Contains(t, restoreStr, "Restored key: user:2", "Should restore user:2")
	assert.NotContains(t, restoreStr, "Restored key: session:abc", "Should not restore session key")
	assert.NotContains(t, restoreStr, "Restored key: config:main", "Should not restore config key")
	assert.NotContains(t, restoreStr, "Restored key: temp:xyz", "Should not restore temp key")

	// Step 3: Test restore with exclude filter (exclude temp keys)
	restoreCmd2 := exec.CommandContext(ctx, flareAdminPath,
		"--index-server", flareIndexServer,
		"--index-server-port", flareIndexServerPort,
		"restore",
		"--input", dumpFile,
		"--exclude", "temp",
		"--print-keys",
		"localhost:12124",
	)

	restoreOutput2, err := restoreCmd2.Output()
	require.NoError(t, err, "Restore with exclude filter failed: %s", string(restoreOutput2))

	restoreStr2 := string(restoreOutput2)
	
	// Should restore everything except temp keys
	assert.Contains(t, restoreStr2, "Restored key: user:1", "Should restore user:1")
	assert.Contains(t, restoreStr2, "Restored key: user:2", "Should restore user:2")
	assert.Contains(t, restoreStr2, "Restored key: session:abc", "Should restore session key")
	assert.Contains(t, restoreStr2, "Restored key: config:main", "Should restore config key")
	assert.NotContains(t, restoreStr2, "Restored key: temp:xyz", "Should not restore temp key")

	t.Logf("Successfully tested restore filters")
}