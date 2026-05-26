#!/usr/bin/env bash
# =============================================================================
# rotate-jwt-secret.sh — Generate a new JWT secret and print rotation steps
# Usage: ./aethel-scripts/rotate-jwt-secret.sh
#
# SECURITY: This script never writes the secret to disk.
# The secret is printed to stdout only — pipe to your clipboard or secret tool.
# =============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

if ! command -v openssl &>/dev/null; then
    echo -e "${RED}[ERROR]${RESET} openssl is required but not installed." >&2
    exit 1
fi

# Generate a cryptographically secure 64-byte random secret (base64 encoded)
NEW_SECRET="$(openssl rand -base64 64 | tr -d '\n')"

echo ""
echo -e "${BOLD}JWT Secret Rotation${RESET}"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo -e "${GREEN}New JWT secret (copy it now — it will not be shown again):${RESET}"
echo ""
echo "  $NEW_SECRET"
echo ""
echo "─────────────────────────────────────────────────────────────────"
echo -e "${YELLOW}IMPORTANT: Do NOT save this value to disk or log files.${RESET}"
echo ""
echo -e "${BOLD}Rotation checklist — update ALL environments:${RESET}"
echo ""
echo -e "  ${BOLD}1. Development (.env)${RESET}"
echo "     Edit your local .env file:"
echo "       AETHEL_JWT_SECRET=<new-value>"
echo "     Then restart the backend: make dev-be"
echo ""
echo -e "  ${BOLD}2. Staging (Kubernetes secret)${RESET}"
echo "     kubectl create secret generic aethel-core-secret \\"
echo "       --namespace=aethel-workspace-staging \\"
echo "       --from-literal=AETHEL_JWT_SECRET='<new-value>' \\"
echo "       --dry-run=client -o yaml | kubectl apply -f -"
echo "     kubectl rollout restart deployment/aethel-core \\"
echo "       --namespace=aethel-workspace-staging"
echo ""
echo -e "  ${BOLD}3. Production (Kubernetes secret)${RESET}"
echo "     kubectl create secret generic aethel-core-secret \\"
echo "       --namespace=aethel-workspace \\"
echo "       --from-literal=AETHEL_JWT_SECRET='<new-value>' \\"
echo "       --dry-run=client -o yaml | kubectl apply -f -"
echo "     kubectl rollout restart deployment/aethel-core \\"
echo "       --namespace=aethel-workspace"
echo ""
echo -e "  ${BOLD}4. HashiCorp Vault (if used)${RESET}"
echo "     vault kv put secret/aethel/backend AETHEL_JWT_SECRET='<new-value>'"
echo "     Then trigger a pod refresh or use Vault Agent Injector auto-reload."
echo ""
echo -e "${RED}Note:${RESET} All existing sessions will be invalidated immediately after rotation."
echo "      Users will need to log in again. Plan accordingly for production."
echo ""
