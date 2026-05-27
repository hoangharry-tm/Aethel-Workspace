package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"aethel-core/internal/domain"
	"aethel-core/internal/rbac"
	"aethel-core/internal/service"
)

type WorkflowHandler struct {
	svc *service.WorkflowService
}

func NewWorkflowHandler(svc *service.WorkflowService) *WorkflowHandler {
	return &WorkflowHandler{svc: svc}
}

func (h *WorkflowHandler) GetMinuteSheet(w http.ResponseWriter, r *http.Request) {
	orgIDStr, _ := rbac.OrgIDFromCtx(r.Context())
	orgID, _ := uuid.Parse(orgIDStr)
	dispatchID, _ := uuid.Parse(chi.URLParam(r, "id"))

	ms, err := h.svc.GetMinuteSheet(r.Context(), orgID, dispatchID)
	if err == domain.ErrNotFound {
		writeError(w, "minute sheet not found", http.StatusNotFound)
		return
	}
	if err != nil {
		writeError(w, "failed to get minute sheet", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, ms)
}

func (h *WorkflowHandler) ListGreenNotes(w http.ResponseWriter, r *http.Request) {
	orgIDStr, _ := rbac.OrgIDFromCtx(r.Context())
	orgID, _ := uuid.Parse(orgIDStr)
	minuteSheetID, _ := uuid.Parse(chi.URLParam(r, "id"))

	notes, err := h.svc.ListGreenNotes(r.Context(), orgID, minuteSheetID)
	if err != nil {
		writeError(w, "failed to list green notes", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, notes)
}

func (h *WorkflowHandler) AppendGreenNote(w http.ResponseWriter, r *http.Request) {
	orgIDStr, _ := rbac.OrgIDFromCtx(r.Context())
	userIDStr, _ := rbac.UserIDFromCtx(r.Context())
	orgID, _ := uuid.Parse(orgIDStr)
	authorID, _ := uuid.Parse(userIDStr)
	minuteSheetID, _ := uuid.Parse(chi.URLParam(r, "id"))

	var req struct {
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Content == "" {
		writeError(w, "content is required", http.StatusBadRequest)
		return
	}

	note, err := h.svc.AppendGreenNote(r.Context(), orgID, minuteSheetID, authorID, req.Content, clientIP(r))
	if err == domain.ErrHashChainBroken {
		writeError(w, "hash chain broken — chain integrity violation detected", http.StatusConflict)
		return
	}
	if err != nil {
		writeError(w, "failed to append green note", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, note)
}

func (h *WorkflowHandler) ApproveMinuteSheet(w http.ResponseWriter, r *http.Request) {
	orgIDStr, _ := rbac.OrgIDFromCtx(r.Context())
	userIDStr, _ := rbac.UserIDFromCtx(r.Context())
	orgID, _ := uuid.Parse(orgIDStr)
	approverID, _ := uuid.Parse(userIDStr)
	minuteSheetID, _ := uuid.Parse(chi.URLParam(r, "id"))

	if err := h.svc.ApproveMinuteSheet(r.Context(), orgID, minuteSheetID, approverID); err != nil {
		writeError(w, "failed to approve minute sheet", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
