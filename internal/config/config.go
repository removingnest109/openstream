package config

import (
	"os"
	"path/filepath"
	"strconv"
	"time"
)

type Config struct {
	Port            int
	DBPath          string
	MusicLibrary    string
	StaticDir       string
	LogoFallback    string
	ScanInterval    time.Duration
	MaxUploadSizeMB int64
}

func Load() Config {
	cwd, _ := os.Getwd()
	return Config{
		Port:            envInt("PORT", 9090),
		DBPath:          env("DB_PATH", filepath.Join(cwd, "openstream.db")),
		MusicLibrary:    env("MUSIC_LIBRARY_PATH", filepath.Join(cwd, "music")),
		StaticDir:       env("STATIC_DIR", filepath.Join(cwd, "..", "web", "build")),
		LogoFallback:    env("LOGO_FALLBACK_PATH", filepath.Join(cwd, "..", "web", "src", "logo.svg")),
		ScanInterval:    envDuration("SCAN_INTERVAL", 5*time.Minute),
		MaxUploadSizeMB: int64(envInt("MAX_UPLOAD_MB", 1024)),
	}
}

func env(key, fallback string) string {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	return v
}

func envInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}

func envDuration(key string, fallback time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return fallback
	}
	return d
}
