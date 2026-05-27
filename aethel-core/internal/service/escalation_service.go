package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"aethel-core/internal/domain"
)

type EscalationService struct {
	dispatches      domain.DispatchRepository
	escalationRules domain.EscalationRuleRepository
	events          domain.DispatchEventRepository
	audit           domain.AuditRepository
}

func NewEscalationService(
	dispatches domain.DispatchRepository,
	escalationRules domain.EscalationRuleRepository,
	events domain.DispatchEventRepository,
	audit domain.AuditRepository,
) *EscalationService {
	return &EscalationService{
		dispatches:      dispatches,
		escalationRules: escalationRules,
		events:          events,
		audit:           audit,
	}
}

// EvaluateForOrg evaluates all active escalation rules for the given org and
// escalates any qualifying dispatches. Called by the escalation worker.
func (s *EscalationService) EvaluateForOrg(ctx context.Context, orgID uuid.UUID) error {
	rules, err := s.escalationRules.List(ctx, orgID)
	if err != nil {
		return fmt.Errorf("list escalation rules for org %s: %w", orgID, err)
	}

	// Fetch all active dispatches for the org.
	dispatches, err := s.dispatches.ListInbox(ctx, orgID, uuid.UUID{}, domain.Page{Limit: 500, Offset: 0})
	if err != nil {
		return fmt.Errorf("list dispatches for org %s: %w", orgID, err)
	}

	now := time.Now()
	for _, d := range dispatches {
		if d.IsEscalated {
			continue
		}
		for _, rule := range rules {
			if !rule.IsActive {
				continue
			}
			if d.OverdueAt != nil && now.After(*d.OverdueAt) {
				if s.ruleApplies(&d, &rule) {
					if err := s.escalate(ctx, orgID, &d); err != nil {
						return fmt.Errorf("escalate dispatch %s: %w", d.ID, err)
					}
					break
				}
			}
		}
	}
	return nil
}

func (s *EscalationService) ruleApplies(d *domain.Dispatch, rule *domain.EscalationRule) bool {
	if rule.DocumentTypeID != nil && d.DocumentTypeID != *rule.DocumentTypeID {
		return false
	}
	if rule.PriorityLevel != nil && string(d.PriorityLevel) != *rule.PriorityLevel {
		return false
	}
	return true
}

func (s *EscalationService) escalate(ctx context.Context, orgID uuid.UUID, d *domain.Dispatch) error {
	if err := s.dispatches.Escalate(ctx, orgID, d.ID); err != nil {
		return err
	}
	_ = s.events.Create(ctx, &domain.DispatchEvent{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DispatchID:     d.ID,
		EventType:      "ESCALATED_BY_RULE",
	})
	return nil
}
