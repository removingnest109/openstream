package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/removingnest109/openstream/go-openstream/internal/api"
	"github.com/removingnest109/openstream/go-openstream/internal/config"
	"github.com/removingnest109/openstream/go-openstream/internal/db"
	"github.com/removingnest109/openstream/go-openstream/internal/ingest"
	"github.com/removingnest109/openstream/go-openstream/internal/worker"
)

func main() {
	cfg := config.Load()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	if err := os.MkdirAll(filepath.Dir(cfg.DBPath), 0o755); err != nil {
		logger.Error("failed creating db directory", "err", err)
		os.Exit(1)
	}

	store, err := db.Open(cfg.DBPath)
	if err != nil {
		logger.Error("failed opening database", "err", err)
		os.Exit(1)
	}
	defer store.Close()

	ingestService := ingest.NewService(store, cfg.MusicLibrary, cfg.LogoFallback, logger)
	workerSvc := worker.NewScannerWorker(ingestService, cfg.ScanInterval, logger)
	server := api.NewServer(store, ingestService, cfg.StaticDir, cfg.MaxUploadSizeMB, logger)

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	workerSvc.Start(ctx)

	addr := fmt.Sprintf("0.0.0.0:%d", cfg.Port)
	if err := api.RunServer(ctx, addr, server.Handler(), logger); err != nil {
		logger.Error("server stopped with error", "err", err)
		os.Exit(1)
	}
}
