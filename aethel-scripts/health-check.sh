#!/usr/bin/env bash
# =============================================================================
# health-check.sh — Verify all Aethel services are running and reachable
# Usage: ./aethel-scripts/health-check.sh
# =============================================================================
set -euo pipefail

BACKEND_URL="${AETHEL_BACKEND_URL:-http://localhost:8080}"
FRONTEND_URL="${AETHEL_FRONTEND_URL:-http://localhost:3000}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-aethel_dev}"
DB_USER="${POSTGRES_USER:-aethel}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

PASS="${GREEN}PASS${RESET}"
FAIL="${RED}FAIL${RESET}"
SKIP="${YELLOW}SKIP${RESET}"

declare -a RESULTS=()
OVERALL=0

check() {
    local name="$1"
    local status="$2"
    local detail="${3:-}"
    if [[ "$status" == "pass" ]]; then
        RESULTS+=("$(printf '  %-30s %b  %s' "$name" "$PASS" "$detail")")
    elif [[ "$status" == "skip" ]]; then
        RESULTS+=("$(printf '  %-30s %b  %s' "$name" "$SKIP" "$detail")")
    else
        RESULTS+=("$(printf '  %-30s %b  %s' "$name" "$FAIL" "$detail")")
        OVERALL=1
    fi
}

echo ""
echo -e "${BOLD}Aethel Workspace — Service Health Check${RESET}"
echo -e "$(date)"
echo ""

# ---------------------------------------------------------------------------
# Backend /health endpoint
# ---------------------------------------------------------------------------
if BACKEND_HTTP=$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "$BACKEND_URL/health" 2>/dev/null); then
    if [[ "$BACKEND_HTTP" == "200" ]]; then
        check "Backend /health" "pass" "$BACKEND_URL"
    else
        check "Backend /health" "fail" "HTTP $BACKEND_HTTP (expected 200)"
    fi
else
    check "Backend /health" "fail" "Could not connect to $BACKEND_URL"
fi

# ---------------------------------------------------------------------------
# Backend /ready endpoint
# ---------------------------------------------------------------------------
if READY_HTTP=$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "$BACKEND_URL/ready" 2>/dev/null); then
    if [[ "$READY_HTTP" == "200" ]]; then
        check "Backend /ready" "pass" "$BACKEND_URL"
    else
        check "Backend /ready" "fail" "HTTP $READY_HTTP (expected 200)"
    fi
else
    check "Backend /ready" "fail" "Could not connect to $BACKEND_URL"
fi

# ---------------------------------------------------------------------------
# Frontend
# ---------------------------------------------------------------------------
if FE_HTTP=$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" "$FRONTEND_URL" 2>/dev/null); then
    if [[ "$FE_HTTP" =~ ^(200|301|302)$ ]]; then
        check "Frontend" "pass" "$FRONTEND_URL (HTTP $FE_HTTP)"
    else
        check "Frontend" "fail" "HTTP $FE_HTTP"
    fi
else
    check "Frontend" "fail" "Could not connect to $FRONTEND_URL"
fi

# ---------------------------------------------------------------------------
# PostgreSQL connectivity
# ---------------------------------------------------------------------------
if command -v psql &>/dev/null; then
    if PGPASSWORD="${POSTGRES_PASSWORD:-}" psql \
        -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "SELECT 1;" &>/dev/null 2>&1; then
        check "PostgreSQL" "pass" "$DB_HOST:$DB_PORT/$DB_NAME"
    else
        check "PostgreSQL" "fail" "Could not connect to $DB_HOST:$DB_PORT/$DB_NAME as $DB_USER"
    fi
elif command -v nc &>/dev/null; then
    if nc -z "$DB_HOST" "$DB_PORT" &>/dev/null 2>&1; then
        check "PostgreSQL (port)" "pass" "$DB_HOST:$DB_PORT reachable (psql not installed)"
    else
        check "PostgreSQL (port)" "fail" "$DB_HOST:$DB_PORT not reachable"
    fi
else
    check "PostgreSQL" "skip" "Neither psql nor nc installed — cannot test"
fi

# ---------------------------------------------------------------------------
# Docker daemon
# ---------------------------------------------------------------------------
if docker info &>/dev/null 2>&1; then
    check "Docker daemon" "pass" "$(docker version --format 'Docker {{.Server.Version}}')"
else
    check "Docker daemon" "fail" "Docker not running or not installed"
fi

# ---------------------------------------------------------------------------
# Print results table
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}Results:${RESET}"
echo "  ─────────────────────────────────────────────────────"
for line in "${RESULTS[@]}"; do
    echo -e "$line"
done
echo "  ─────────────────────────────────────────────────────"

if [[ $OVERALL -eq 0 ]]; then
    echo -e "\n  ${GREEN}All checks passed.${RESET}\n"
else
    echo -e "\n  ${RED}One or more checks failed. Review the output above.${RESET}\n"
    exit 1
fi
