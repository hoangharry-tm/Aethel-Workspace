#!/usr/bin/env bash
# =============================================================================
# db-backup.sh — PostgreSQL backup with optional S3 upload
# Usage: ./aethel-scripts/db-backup.sh [--env development|staging|production]
#
# Required env vars (or set in .env):
#   POSTGRES_HOST     DB host (default: localhost)
#   POSTGRES_PORT     DB port (default: 5432)
#   POSTGRES_DB       Database name
#   POSTGRES_USER     Database user
#   POSTGRES_PASSWORD Database password
#
# Optional:
#   AETHEL_BACKUP_S3_BUCKET  S3 bucket name (e.g. my-aethel-backups)
#                            If set, backup is uploaded via `aws s3 cp`.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()  { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error() { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
ENV="development"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env)
            ENV="$2"
            shift 2
            ;;
        *)
            error "Unknown argument: $1"
            echo "Usage: $0 [--env development|staging|production]"
            exit 1
            ;;
    esac
done

# Validate environment
case "$ENV" in
    development|staging|production) ;;
    *)
        error "Invalid --env value: $ENV (must be: development, staging, production)"
        exit 1
        ;;
esac

info "Environment: $ENV"

# ---------------------------------------------------------------------------
# Load .env for development (skip for staging/production — use mounted env)
# ---------------------------------------------------------------------------
if [[ "$ENV" == "development" ]] && [[ -f "$REPO_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    set -o allexport && source "$REPO_ROOT/.env" && set +o allexport
    info "Loaded .env"
fi

# ---------------------------------------------------------------------------
# Configuration (with defaults)
# ---------------------------------------------------------------------------
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:?POSTGRES_DB is required}"
DB_USER="${POSTGRES_USER:?POSTGRES_USER is required}"
DB_PASS="${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
S3_BUCKET="${AETHEL_BACKUP_S3_BUCKET:-}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
FILENAME="aethel-${ENV}-${TIMESTAMP}.sql.gz"
BACKUP_DIR="${TMPDIR:-/tmp}"
BACKUP_PATH="$BACKUP_DIR/$FILENAME"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
for cmd in pg_dump gzip; do
    if ! command -v "$cmd" &>/dev/null; then
        error "$cmd is required but not installed."
        exit 1
    fi
done

if [[ -n "$S3_BUCKET" ]] && ! command -v aws &>/dev/null; then
    error "AETHEL_BACKUP_S3_BUCKET is set but 'aws' CLI is not installed."
    exit 1
fi

# ---------------------------------------------------------------------------
# Run backup
# ---------------------------------------------------------------------------
info "Starting backup of $DB_NAME on $DB_HOST:$DB_PORT..."

PGPASSWORD="$DB_PASS" pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --no-password \
    --format=plain \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    | gzip -9 > "$BACKUP_PATH"

BACKUP_SIZE="$(du -sh "$BACKUP_PATH" | cut -f1)"
info "Backup written to: $BACKUP_PATH ($BACKUP_SIZE)"

# ---------------------------------------------------------------------------
# Optional S3 upload
# ---------------------------------------------------------------------------
if [[ -n "$S3_BUCKET" ]]; then
    S3_KEY="backups/${ENV}/${FILENAME}"
    S3_URI="s3://${S3_BUCKET}/${S3_KEY}"
    info "Uploading to $S3_URI..."
    aws s3 cp "$BACKUP_PATH" "$S3_URI" \
        --storage-class STANDARD_IA \
        --sse AES256
    info "Upload complete: $S3_URI"

    # Remove local file after successful upload to S3
    rm -f "$BACKUP_PATH"
    info "Local file removed."
else
    warn "AETHEL_BACKUP_S3_BUCKET not set — backup kept locally at $BACKUP_PATH"
    warn "Copy it to a safe location before it is cleaned up."
fi

info "Backup complete."
