package database

import (
	"context"
	"database/sql"
	"fmt"

	"aethel-core/internal/blueprint"
)

// PreparedQuery holds a compiled statement and its metadata.
type PreparedQuery struct {
	Stmt       *sql.Stmt
	TimeoutMs  int
	Permission string
}

// QueryRegistry maps "group.name" → PreparedQuery.
type QueryRegistry struct {
	stmts    map[string]*PreparedQuery
	defaults blueprint.GlobalQueryDefaults
}

func BuildQueryRegistry(
	ctx context.Context,
	db *sql.DB,
	cfg *blueprint.QueriesConfig,
) (*QueryRegistry, error) {
	reg := &QueryRegistry{
		stmts:    make(map[string]*PreparedQuery),
		defaults: cfg.GlobalQueryDefaults,
	}

	for group, queries := range cfg.Queries {
		for name, q := range queries {
			key := group + "." + name
			stmt, err := db.PrepareContext(ctx, q.Statement)
			if err != nil {
				return nil, fmt.Errorf("prepare query %q: %w", key, err)
			}

			timeoutMs := q.TimeoutMs
			if timeoutMs == 0 {
				timeoutMs = cfg.GlobalQueryDefaults.TimeoutMs
			}

			reg.stmts[key] = &PreparedQuery{
				Stmt:       stmt,
				TimeoutMs:  timeoutMs,
				Permission: q.RequiredPermission,
			}
		}
	}
	return reg, nil
}

// Get returns the prepared query for "group.name". Panics on missing keys —
// this is a programmer error caught at first boot, not at request time.
func (r *QueryRegistry) Get(key string) *PreparedQuery {
	pq, ok := r.stmts[key]
	if !ok {
		panic(fmt.Sprintf("query registry: key %q not found — check queries.yaml", key))
	}
	return pq
}

func (r *QueryRegistry) MaxRowsPerPage() int {
	return r.defaults.MaxRowsPerPage
}
