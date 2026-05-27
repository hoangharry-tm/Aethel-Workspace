package worker

import (
	"context"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"aethel-core/internal/service"
)

// EscalationWorker ticks periodically and evaluates escalation rules for all active orgs.
type EscalationWorker struct {
	svc      *service.EscalationService
	interval time.Duration
	orgIDs   []uuid.UUID
}

func NewEscalationWorker(svc *service.EscalationService, interval time.Duration, orgIDs []uuid.UUID) *EscalationWorker {
	if interval <= 0 {
		interval = 15 * time.Minute
	}
	return &EscalationWorker{svc: svc, interval: interval, orgIDs: orgIDs}
}

// Run starts the worker loop. It blocks until ctx is cancelled.
func (w *EscalationWorker) Run(ctx context.Context) {
	slog.Info("escalation worker started", "interval", w.interval)
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			slog.Info("escalation worker stopped")
			return
		case <-ticker.C:
			w.evaluate(ctx)
		}
	}
}

func (w *EscalationWorker) evaluate(ctx context.Context) {
	for _, orgID := range w.orgIDs {
		if err := w.svc.EvaluateForOrg(ctx, orgID); err != nil {
			slog.Error("escalation evaluation failed", "org", orgID, "err", err)
		}
	}
}
