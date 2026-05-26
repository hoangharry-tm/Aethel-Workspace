#!/usr/bin/env bash
# =============================================================================
# k8s-rollout.sh — Coordinated production rollout
#
# Steps:
#   1. Run `aethel migrate up` as a Kubernetes Job
#   2. Wait for the migration Job to complete successfully
#   3. Restart the aethel-core deployment (rolling update)
#
# Usage:
#   ./aethel-scripts/k8s-rollout.sh [--namespace <ns>]
#
# Flags:
#   --namespace   K8s namespace to target (default: aethel-workspace)
# =============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}$*${RESET}"; }

# ---------------------------------------------------------------------------
# Defaults / argument parsing
# ---------------------------------------------------------------------------
NAMESPACE="aethel-workspace"
JOB_TIMEOUT=300  # seconds to wait for migration job

while [[ $# -gt 0 ]]; do
    case "$1" in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        *)
            error "Unknown argument: $1"
            echo "Usage: $0 [--namespace <namespace>]"
            exit 1
            ;;
    esac
done

info "Target namespace: $NAMESPACE"

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
if ! command -v kubectl &>/dev/null; then
    error "kubectl is required but not installed."
    exit 1
fi

# Verify cluster connectivity
if ! kubectl cluster-info &>/dev/null 2>&1; then
    error "Cannot connect to Kubernetes cluster. Check your KUBECONFIG."
    exit 1
fi

info "kubectl cluster-info: OK"

# ---------------------------------------------------------------------------
# Step 1: Create migration Job
# ---------------------------------------------------------------------------
section "Step 1/3 — Creating migration Job"

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
JOB_NAME="aethel-migrate-${TIMESTAMP}"

# Get current backend image from the deployment
BACKEND_IMAGE="$(kubectl get deployment aethel-core \
    --namespace="$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"

if [[ -z "$BACKEND_IMAGE" ]]; then
    error "Could not determine backend image from deployment aethel-core in namespace $NAMESPACE."
    error "Ensure the deployment exists before running a rollout."
    exit 1
fi

info "Using image: $BACKEND_IMAGE"
info "Creating Job: $JOB_NAME"

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: aethel-migrate
    app.kubernetes.io/part-of: aethel-workspace
  annotations:
    rollout-timestamp: "${TIMESTAMP}"
spec:
  ttlSecondsAfterFinished: 3600
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrator
          image: ${BACKEND_IMAGE}
          command: ["/bin/aethel", "migrate", "up"]
          envFrom:
            - configMapRef:
                name: aethel-core-config
            - secretRef:
                name: aethel-core-secret
          resources:
            requests:
              memory: 64Mi
              cpu: 50m
            limits:
              memory: 256Mi
              cpu: 200m
EOF

info "Job created: $JOB_NAME"

# ---------------------------------------------------------------------------
# Step 2: Wait for migration Job to complete
# ---------------------------------------------------------------------------
section "Step 2/3 — Waiting for migration Job to complete (timeout: ${JOB_TIMEOUT}s)"

START_TIME="$(date +%s)"

while true; do
    NOW="$(date +%s)"
    ELAPSED=$(( NOW - START_TIME ))

    if [[ $ELAPSED -ge $JOB_TIMEOUT ]]; then
        error "Migration Job timed out after ${JOB_TIMEOUT}s."
        kubectl logs "job/${JOB_NAME}" --namespace="$NAMESPACE" || true
        kubectl delete job "${JOB_NAME}" --namespace="$NAMESPACE" --ignore-not-found
        exit 1
    fi

    JOB_STATUS="$(kubectl get job "${JOB_NAME}" \
        --namespace="$NAMESPACE" \
        -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo 'Pending')"

    case "$JOB_STATUS" in
        Complete)
            info "Migration Job completed successfully (${ELAPSED}s)."
            kubectl logs "job/${JOB_NAME}" --namespace="$NAMESPACE" || true
            break
            ;;
        Failed)
            error "Migration Job failed."
            kubectl logs "job/${JOB_NAME}" --namespace="$NAMESPACE" || true
            exit 1
            ;;
        *)
            echo -ne "\r  Waiting... ${ELAPSED}s elapsed (status: ${JOB_STATUS})    "
            sleep 5
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Step 3: Rolling restart of aethel-core deployment
# ---------------------------------------------------------------------------
section "Step 3/3 — Rolling restart of aethel-core deployment"

info "Triggering rollout restart..."
kubectl rollout restart deployment/aethel-core --namespace="$NAMESPACE"

info "Waiting for rollout to complete..."
kubectl rollout status deployment/aethel-core \
    --namespace="$NAMESPACE" \
    --timeout=5m

info "Rollout complete."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}Production rollout finished successfully.${RESET}"
echo ""
kubectl get pods --namespace="$NAMESPACE" --selector="app.kubernetes.io/name=aethel-core"
echo ""
