package worker

import (
	"context"
	"log/slog"
	"time"

	"github.com/removingnest109/openstream/go-openstream/internal/ingest"
)

type ScannerWorker struct {
	service  *ingest.Service
	interval time.Duration
	logger   *slog.Logger
}

func NewScannerWorker(service *ingest.Service, interval time.Duration, logger *slog.Logger) *ScannerWorker {
	return &ScannerWorker{service: service, interval: interval, logger: logger}
}

func (w *ScannerWorker) Start(ctx context.Context) {
	go func() {
		if err := w.service.ScanLibrary(ctx); err != nil {
			w.logger.Warn("initial scan failed", "err", err)
		}

		ticker := time.NewTicker(w.interval)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				if err := w.service.ScanLibrary(ctx); err != nil {
					w.logger.Warn("periodic scan failed", "err", err)
				}
			}
		}
	}()
}
