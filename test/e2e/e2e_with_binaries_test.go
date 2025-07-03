package e2e

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"
)

func getPrebuiltBinaries(t *testing.T) (string, string) {
	projectRoot, err := filepath.Abs("../..")
	require.NoError(t, err)
	
	// Check if pre-built Linux binaries exist
	flareAdminPath := filepath.Join(projectRoot, "build", "flare-admin-linux")
	flareStatsPath := filepath.Join(projectRoot, "build", "flare-stats-linux")
	
	// If running in CI/container, use the Linux binaries
	if os.Getenv("USE_LINUX_BINARIES") == "true" {
		if _, err := os.Stat(flareAdminPath); os.IsNotExist(err) {
			t.Skip("Pre-built Linux binaries not found. Run: make build-linux")
		}
		return flareAdminPath, flareStatsPath
	}
	
	// Otherwise, build for current platform
	return buildBinaries(t)
}

// Use this function in your tests instead of buildBinaries()
// Example:
// func TestWithPrebuiltBinaries(t *testing.T) {
//     flareAdminPath, flareStatsPath := getPrebuiltBinaries(t)
//     // ... rest of test
// }