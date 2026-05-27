package service

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"aethel-core/internal/domain"
)

type DispatchService struct {
	dispatches     domain.DispatchRepository
	events         domain.DispatchEventRepository
	routingRules   domain.RoutingRuleRepository
	minuteSheets   domain.MinuteSheetRepository
	audit          domain.AuditRepository
}

func NewDispatchService(
	dispatches domain.DispatchRepository,
	events domain.DispatchEventRepository,
	routingRules domain.RoutingRuleRepository,
	minuteSheets domain.MinuteSheetRepository,
	audit domain.AuditRepository,
) *DispatchService {
	return &DispatchService{
		dispatches:   dispatches,
		events:       events,
		routingRules: routingRules,
		minuteSheets: minuteSheets,
		audit:        audit,
	}
}

func (s *DispatchService) Create(ctx context.Context, d *Dispatch, submitterID, orgID uuid.UUID, ip string) (*domain.Dispatch, error) {
	dispatch := &domain.Dispatch{
		ID:                   uuid.New(),
		OrganizationID:       orgID,
		TrackingNumber:       generateTrackingNumber(),
		Direction:            domain.DispatchDirection(d.Direction),
		DocumentTypeID:       d.DocumentTypeID,
		SenderName:           d.SenderName,
		SenderOrganization:   d.SenderOrganization,
		RecipientName:        d.RecipientName,
		RecipientOrganization: d.RecipientOrganization,
		RecipientAddress:     d.RecipientAddress,
		SubmittedByUserID:    submitterID,
		PriorityLevel:        domain.PriorityLevel(d.PriorityLevel),
		StatusState:          domain.StatusPendingAssignment,
		SubjectLine:          d.SubjectLine,
		DeliveryMode:         d.DeliveryMode,
	}

	// Evaluate routing rules.
	rules, err := s.routingRules.List(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("load routing rules: %w", err)
	}

	if dest := s.evaluateRules(dispatch, rules); dest != nil {
		dispatch.AssignedDepartmentID = dest.DepartmentID
		dispatch.AssignedUserID = dest.UserID
	}

	if err := s.dispatches.Create(ctx, dispatch); err != nil {
		return nil, fmt.Errorf("create dispatch: %w", err)
	}

	// Auto-create the minute sheet for every inbound dispatch.
	if dispatch.Direction == domain.DirectionInbound {
		ms := &domain.MinuteSheet{
			ID:             uuid.New(),
			OrganizationID: orgID,
			DispatchID:     dispatch.ID,
			Status:         domain.MinuteSheetOpen,
		}
		if err := s.minuteSheets.Create(ctx, ms); err != nil {
			return nil, fmt.Errorf("create minute sheet: %w", err)
		}
	}

	// Append routing event.
	eventType := "DISPATCH_CREATED"
	if dispatch.AssignedDepartmentID != nil || dispatch.AssignedUserID != nil {
		eventType = "ROUTING_APPLIED"
	}
	_ = s.events.Create(ctx, &domain.DispatchEvent{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DispatchID:     dispatch.ID,
		EventType:      eventType,
		ActorUserID:    &submitterID,
		ToDeptID:       dispatch.AssignedDepartmentID,
		ToUserID:       dispatch.AssignedUserID,
	})

	_ = s.audit.Write(ctx, &domain.AuditEntry{
		OrganizationID:   orgID,
		ActorUserID:      &submitterID,
		ActionEventType:  domain.AuditDispatchCreated,
		TargetResourceID: &dispatch.ID,
		IPAddress:        &ip,
	})

	return dispatch, nil
}

func (s *DispatchService) GetByID(ctx context.Context, orgID, id uuid.UUID) (*domain.Dispatch, error) {
	return s.dispatches.GetByID(ctx, orgID, id)
}

func (s *DispatchService) ListInbox(ctx context.Context, orgID, deptID uuid.UUID, page domain.Page) ([]domain.Dispatch, error) {
	return s.dispatches.ListInbox(ctx, orgID, deptID, page)
}

func (s *DispatchService) ListOutbound(ctx context.Context, orgID uuid.UUID, page domain.Page) ([]domain.Dispatch, error) {
	return s.dispatches.ListOutbound(ctx, orgID, page)
}

func (s *DispatchService) ListByUser(ctx context.Context, orgID, userID uuid.UUID, page domain.Page) ([]domain.Dispatch, error) {
	return s.dispatches.ListByUser(ctx, orgID, userID, page)
}

func (s *DispatchService) UpdateStatus(ctx context.Context, orgID, id, actorID uuid.UUID, status domain.DispatchStatus) error {
	if err := s.dispatches.UpdateStatus(ctx, orgID, id, status); err != nil {
		return err
	}
	return s.events.Create(ctx, &domain.DispatchEvent{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DispatchID:     id,
		EventType:      "STATUS_CHANGED",
		ActorUserID:    &actorID,
	})
}

func (s *DispatchService) Assign(ctx context.Context, orgID, id, actorID uuid.UUID, userID, deptID *uuid.UUID, ip string) error {
	if err := s.dispatches.Assign(ctx, orgID, id, userID, deptID); err != nil {
		return err
	}
	_ = s.events.Create(ctx, &domain.DispatchEvent{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DispatchID:     id,
		EventType:      "MANUALLY_ASSIGNED",
		ActorUserID:    &actorID,
		ToUserID:       userID,
		ToDeptID:       deptID,
	})
	_ = s.audit.Write(ctx, &domain.AuditEntry{
		OrganizationID:   orgID,
		ActorUserID:      &actorID,
		ActionEventType:  domain.AuditDispatchAssigned,
		TargetResourceID: &id,
		IPAddress:        &ip,
	})
	return nil
}

func (s *DispatchService) Acknowledge(ctx context.Context, orgID, id, byUserID uuid.UUID, ip string) error {
	if err := s.dispatches.Acknowledge(ctx, orgID, id, byUserID); err != nil {
		return err
	}
	_ = s.events.Create(ctx, &domain.DispatchEvent{
		ID:             uuid.New(),
		OrganizationID: orgID,
		DispatchID:     id,
		EventType:      "DELIVERY_ACKNOWLEDGED",
		ActorUserID:    &byUserID,
	})
	_ = s.audit.Write(ctx, &domain.AuditEntry{
		OrganizationID:   orgID,
		ActorUserID:      &byUserID,
		ActionEventType:  domain.AuditDispatchDelivered,
		TargetResourceID: &id,
		IPAddress:        &ip,
	})
	return nil
}

func (s *DispatchService) GetTimeline(ctx context.Context, orgID, dispatchID uuid.UUID) ([]domain.DispatchEvent, error) {
	return s.events.ListByDispatch(ctx, orgID, dispatchID)
}

// evaluateRules returns the first destination matched by routing rules in priority order.
func (s *DispatchService) evaluateRules(d *domain.Dispatch, rules []domain.RoutingRule) *domain.RuleDestination {
	for _, rule := range rules {
		if !rule.IsActive {
			continue
		}
		if s.ruleMatches(d, rule.Conditions) && len(rule.Destinations) > 0 {
			return &rule.Destinations[0]
		}
	}
	return nil
}

func (s *DispatchService) ruleMatches(d *domain.Dispatch, conditions []domain.RuleCondition) bool {
	for _, c := range conditions {
		if !conditionMatch(d, c) {
			return false
		}
	}
	return true
}

func conditionMatch(d *domain.Dispatch, c domain.RuleCondition) bool {
	var fieldValue string
	switch c.FieldName {
	case "document_type_id":
		fieldValue = d.DocumentTypeID.String()
	case "priority_level":
		fieldValue = string(d.PriorityLevel)
	case "direction":
		fieldValue = string(d.Direction)
	case "sender_organization":
		if d.SenderOrganization != nil {
			fieldValue = *d.SenderOrganization
		}
	default:
		return false
	}

	switch c.Operator {
	case "eq", "=":
		return fieldValue == c.MatchValue
	case "neq", "!=":
		return fieldValue != c.MatchValue
	default:
		return false
	}
}

func generateTrackingNumber() string {
	return fmt.Sprintf("TRK-%d", time.Now().UnixNano())
}

// CreateDispatch is the input DTO for creating a new dispatch.
type Dispatch struct {
	Direction             string
	DocumentTypeID        uuid.UUID
	SenderName            string
	SenderOrganization    *string
	RecipientName         *string
	RecipientOrganization *string
	RecipientAddress      *string
	PriorityLevel         string
	SubjectLine           *string
	DeliveryMode          *string
}
