package config

import (
	"sync"
	"time"

	"github.com/google/uuid"
)

type cachedEntry struct {
	config    *OrgConfig
	expiresAt time.Time
}

// ConfigCache is a per-org in-memory cache with TTL. Safe for concurrent use.
type ConfigCache struct {
	mu      sync.RWMutex
	entries map[uuid.UUID]*cachedEntry
}

func NewConfigCache() *ConfigCache {
	return &ConfigCache{
		entries: make(map[uuid.UUID]*cachedEntry),
	}
}

func (c *ConfigCache) Get(orgID uuid.UUID) (*OrgConfig, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	e, ok := c.entries[orgID]
	if !ok || time.Now().After(e.expiresAt) {
		return nil, false
	}
	return e.config, true
}

func (c *ConfigCache) Set(orgID uuid.UUID, cfg *OrgConfig, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[orgID] = &cachedEntry{
		config:    cfg,
		expiresAt: time.Now().Add(ttl),
	}
}

func (c *ConfigCache) Invalidate(orgID uuid.UUID) {
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.entries, orgID)
}
