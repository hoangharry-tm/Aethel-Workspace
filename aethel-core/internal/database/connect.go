package database

import (
	"database/sql"
	"fmt"
	"os"
	"time"

	_ "github.com/lib/pq"
	"aethel-core/internal/blueprint"
)

func Open(cfg blueprint.EnvironmentConfig) (*sql.DB, error) {
	dsn, err := buildDSN(cfg.Connection)
	if err != nil {
		return nil, err
	}
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}

	p := cfg.Pooling
	db.SetMaxOpenConns(p.MaxOpenConnections)
	db.SetMaxIdleConns(p.MaxIdleConnections)
	db.SetConnMaxLifetime(time.Duration(p.ConnectionMaxLifetimeMinutes) * time.Minute)
	db.SetConnMaxIdleTime(time.Duration(p.ConnectionMaxIdleTimeMinutes) * time.Minute)

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	return db, nil
}

func buildDSN(c blueprint.ConnectionConfig) (string, error) {
	if c.ConnectionStringEnv != "" {
		dsn := os.Getenv(c.ConnectionStringEnv)
		if dsn == "" {
			return "", fmt.Errorf(
				"connection_string_env=%q is set but the env var is empty",
				c.ConnectionStringEnv,
			)
		}
		return dsn, nil
	}

	password := os.Getenv("AETHEL_DB_PASSWORD")
	dsn := fmt.Sprintf(
		"host=%s port=%d dbname=%s user=%s password=%s sslmode=%s",
		c.Host, c.Port, c.Database, c.User, password, c.SSLMode,
	)
	if c.SSLRootCertPath != "" {
		dsn += " sslrootcert=" + c.SSLRootCertPath
	}
	return dsn, nil
}
