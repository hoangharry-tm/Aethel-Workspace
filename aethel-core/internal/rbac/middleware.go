package rbac

import (
	"context"
	"net/http"

	"aethel-core/internal/domain"
)

type ctxKey string

const (
	ctxUserID   ctxKey = "userID"
	ctxOrgID    ctxKey = "orgID"
	ctxUserRole ctxKey = "userRole"
)

// rolePermissions maps roles to the set of permissions they hold.
var rolePermissions = map[domain.UserRole]map[string]bool{
	domain.RoleSysAdmin: {
		"dispatch.view":    true,
		"dispatch.create":  true,
		"dispatch.assign":  true,
		"dispatch.deliver": true,
		"workflow.view":    true,
		"workflow.approve": true,
		"admin.access":     true,
		"admin.audit":      true,
	},
	domain.RoleAdmin: {
		"dispatch.view":    true,
		"dispatch.create":  true,
		"dispatch.assign":  true,
		"dispatch.deliver": true,
		"workflow.view":    true,
		"workflow.approve": true,
		"admin.access":     true,
	},
	domain.RoleReception: {
		"dispatch.view":    true,
		"dispatch.create":  true,
		"dispatch.assign":  true,
		"dispatch.deliver": true,
		"workflow.view":    true,
	},
	domain.RoleUser: {
		"dispatch.view":    true,
		"workflow.view":    true,
		"workflow.approve": true,
	},
}

// Require returns middleware that enforces the given permission.
// Routes with permission "public" skip the JWT check entirely.
func Require(permission string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if permission == "public" {
				next.ServeHTTP(w, r)
				return
			}

			role, ok := r.Context().Value(ctxUserRole).(domain.UserRole)
			if !ok || role == "" {
				http.Error(w, "unauthorized", http.StatusUnauthorized)
				return
			}

			perms, exists := rolePermissions[role]
			if !exists || !perms[permission] {
				http.Error(w, "forbidden", http.StatusForbidden)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// SetUserContext stores auth claims on the request context.
func SetUserContext(ctx context.Context, userID, orgID string, role domain.UserRole) context.Context {
	ctx = context.WithValue(ctx, ctxUserID, userID)
	ctx = context.WithValue(ctx, ctxOrgID, orgID)
	ctx = context.WithValue(ctx, ctxUserRole, role)
	return ctx
}

// UserIDFromCtx retrieves the authenticated user ID string from context.
func UserIDFromCtx(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(ctxUserID).(string)
	return v, ok
}

// OrgIDFromCtx retrieves the organization ID string from context.
func OrgIDFromCtx(ctx context.Context) (string, bool) {
	v, ok := ctx.Value(ctxOrgID).(string)
	return v, ok
}

// RoleFromCtx retrieves the user role from context.
func RoleFromCtx(ctx context.Context) (domain.UserRole, bool) {
	v, ok := ctx.Value(ctxUserRole).(domain.UserRole)
	return v, ok
}
