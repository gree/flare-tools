package config

import (
	"os"
	"strconv"
	"strings"
)

type Config struct {
	IndexServer     string
	IndexServerPort int
	Debug           bool
	Warn            bool
	DryRun          bool
	LogFile         string
	ShowQPS         bool
	Wait            int
	Count           int
	Delimiter       string
	Force           bool
	Retry           int
	BandwidthLimit  int64
}

func NewConfig() *Config {
	cfg := &Config{
		IndexServer:     "127.0.0.1",
		IndexServerPort: 12120,
		Debug:           false,
		Warn:            false,
		DryRun:          false,
		LogFile:         "",
		ShowQPS:         false,
		Wait:            0,
		Count:           1,
		Delimiter:       "\t",
		Force:           false,
		Retry:           10,
		BandwidthLimit:  0,
	}

	if envServer := os.Getenv("FLARE_INDEX_SERVER"); envServer != "" {
		if strings.Contains(envServer, ":") {
			parts := strings.Split(envServer, ":")
			cfg.IndexServer = parts[0]
			if port, err := strconv.Atoi(parts[1]); err == nil {
				cfg.IndexServerPort = port
			}
		} else {
			cfg.IndexServer = envServer
		}
	}

	if envPort := os.Getenv("FLARE_INDEX_SERVER_PORT"); envPort != "" {
		if port, err := strconv.Atoi(envPort); err == nil {
			cfg.IndexServerPort = port
		}
	}

	return cfg
}

func (c *Config) GetIndexServerAddress() string {
	return c.IndexServer + ":" + strconv.Itoa(c.IndexServerPort)
}