package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type MinuteSheetStatus string

const (
	MinuteSheetOpen     MinuteSheetStatus = "OPEN"
	MinuteSheetApproved MinuteSheetStatus = "APPROVED"
	MinuteSheetRejected MinuteSheetStatus = "REJECTED"
)

type MinuteSheet struct {
	ID             uuid.UUID         `json:"id"`
	OrganizationID uuid.UUID         `json:"organizationId"`
	DispatchID     uuid.UUID         `json:"dispatchId"`
	Status         MinuteSheetStatus `json:"status"`
	ApprovedByID   *uuid.UUID        `json:"approvedById,omitempty"`
	ApprovedAt     *time.Time        `json:"approvedAt,omitempty"`
	CreatedAt      time.Time         `json:"createdAt"`
	UpdatedAt      time.Time         `json:"updatedAt"`
}

type GreenNote struct {
	ID                uuid.UUID `json:"id"`
	OrganizationID    uuid.UUID `json:"organizationId"`
	MinuteSheetID     uuid.UUID `json:"minuteSheetId"`
	AuthorOfficerID   uuid.UUID `json:"authorOfficerId"`
	SequenceOrder     int       `json:"sequenceOrder"`
	ContentBody       string    `json:"contentBody"`
	CryptographicHash string    `json:"cryptographicHash"`
	PreviousHash      string    `json:"previousHash"`
	DigitalSignature  *string   `json:"digitalSignature,omitempty"`
	CreatedAt         time.Time `json:"createdAt"`
}

type MinuteSheetRepository interface {
	GetByDispatchID(ctx context.Context, orgID, dispatchID uuid.UUID) (*MinuteSheet, error)
	GetByID(ctx context.Context, orgID, id uuid.UUID) (*MinuteSheet, error)
	Create(ctx context.Context, ms *MinuteSheet) error
	Approve(ctx context.Context, orgID, id uuid.UUID, approverID uuid.UUID) error
}

type GreenNoteRepository interface {
	Create(ctx context.Context, n *GreenNote) error
	ListByMinuteSheet(ctx context.Context, orgID, minuteSheetID uuid.UUID) ([]GreenNote, error)
	GetLastByMinuteSheet(ctx context.Context, orgID, minuteSheetID uuid.UUID) (*GreenNote, error)
}
