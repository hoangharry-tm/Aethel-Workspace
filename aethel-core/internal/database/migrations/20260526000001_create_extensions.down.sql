-- Migration 01 DOWN: Drop extensions.
-- WARNING: Only drop if no other database objects depend on these extensions.

DROP EXTENSION IF EXISTS "pg_trgm";
DROP EXTENSION IF EXISTS "pgcrypto";
DROP EXTENSION IF EXISTS "uuid-ossp";
