#!/usr/bin/env bash
# =============================================================================
# setup-dev.sh — First-time developer environment setup
# Usage: ./aethel-scripts/setup-dev.sh
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}$*${RESET}"; }

# =============================================================================
section "1/4 — Checking required dependencies"
# =============================================================================

MISSING=()

check_cmd() {
    local cmd="$1"
    local label="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        info "$label found: $(command -v "$cmd")"
    else
        warn "$label not found — please install it."
        MISSING+=("$label")
    fi
}

check_cmd go    "Go 1.23+"
check_cmd node  "Node 20+"
check_cmd pnpm  "pnpm"
check_cmd docker "Docker"
check_cmd "docker" "Docker Compose (via docker compose)"
check_cmd kubectl "kubectl"

# Check minimum versions
if command -v go &>/dev/null; then
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    info "Go version: $GO_VERSION"
fi

if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [[ "$NODE_MAJOR" -lt 20 ]]; then
        warn "Node $NODE_VERSION detected — Node 20+ is required."
        MISSING+=("Node 20+")
    else
        info "Node version: $NODE_VERSION"
    fi
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    error "Missing dependencies: ${MISSING[*]}"
    error "Please install the above tools before continuing."
    error "See docs/go-developer-guide.md for setup instructions."
    exit 1
fi

# =============================================================================
section "2/4 — Setting up environment file"
# =============================================================================

ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/.env.example"

if [[ -f "$ENV_FILE" ]]; then
    info ".env already exists — skipping copy."
else
    if [[ -f "$ENV_EXAMPLE" ]]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        info "Copied .env.example → .env"
        warn "Open .env and fill in real values before running 'make dev'."
    else
        error ".env.example not found at $ENV_EXAMPLE"
        exit 1
    fi
fi

# =============================================================================
section "3/4 — Installing frontend dependencies"
# =============================================================================

VIEW_DIR="$REPO_ROOT/aethel-view"

if [[ ! -d "$VIEW_DIR" ]]; then
    error "aethel-view/ not found at $VIEW_DIR"
    exit 1
fi

info "Running pnpm install in aethel-view/..."
(cd "$VIEW_DIR" && pnpm install --frozen-lockfile)
info "Frontend dependencies installed."

# =============================================================================
section "4/4 — Next steps"
# =============================================================================

echo ""
echo -e "${BOLD}Setup complete. Here's what to do next:${RESET}"
echo ""
echo -e "  1. ${YELLOW}Edit .env${RESET} and fill in your database password and JWT secret:"
echo "       POSTGRES_PASSWORD=<your-password>"
echo "       AETHEL_JWT_SECRET=\$(openssl rand -base64 64)"
echo ""
echo -e "  2. ${YELLOW}Start the dev stack:${RESET}"
echo "       make dev"
echo "     Or start services individually:"
echo "       make dev-db      # postgres only"
echo "       make dev-be      # backend only (go run)"
echo "       make dev-fe      # frontend only (nuxt dev)"
echo ""
echo -e "  3. ${YELLOW}Apply database migrations:${RESET}"
echo "       make migrate-up"
echo ""
echo -e "  4. ${YELLOW}Run tests:${RESET}"
echo "       make test"
echo ""
echo -e "  5. ${YELLOW}Read the developer guide:${RESET}"
echo "       docs/go-developer-guide.md"
echo ""
