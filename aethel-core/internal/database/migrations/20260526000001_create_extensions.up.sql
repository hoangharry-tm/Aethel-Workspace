-- Migration 01 UP: Install required PostgreSQL extensions.
-- These must exist before any table using gen_random_uuid(), digest(), or
-- trigram-based indexes is created.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
