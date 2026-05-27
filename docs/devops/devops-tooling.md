# Aethel Workspace — DevSecOps Tooling Recommendations

This document covers the tools used (and recommended) across the Aethel Workspace DevOps
pipeline. It is structured for an on-premise or cloud-self-hosted deployment — no mandatory
third-party SaaS dependencies.

---

## Getting Started — Install These Three First

Before anything else, install these three tools on your workstation and CI runner:

1. **Docker** (`docker`) — required to build and run all containers locally.
   - Install: <https://docs.docker.com/engine/install/>
   - Verify: `docker version`

2. **kubectl** (`kubectl`) — required to interact with Kubernetes.
   - Install: <https://kubernetes.io/docs/tasks/tools/>
   - Verify: `kubectl version --client`

3. **golangci-lint** — required for `make lint-be` and the CI `test-backend` job.
   - Install: `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`
   - Or via their installer script: <https://golangci-lint.run/welcome/install/>
   - Verify: `golangci-lint --version`

---

## Full Tooling Reference

| Category | Tool | Why | Mandatory? |
|---|---|---|---|
| Container registry | GitHub Container Registry (`ghcr.io`) | Free, integrated with GitHub Actions, no separate token management | Yes |
| Local K8s | minikube or kind | Test K8s manifests locally before pushing to staging | Dev only |
| Secret management (dev) | `.env` file (git-ignored) | Simple, zero-dependency local secret management | Yes (dev) |
| Secret management (prod) | HashiCorp Vault (self-hosted) or K8s Secrets | No third-party SaaS; Vault adds dynamic secrets, lease rotation, audit log | Vault for prod |
| Observability: logs | Loki + Promtail | Lightweight, self-hosted, structured log aggregation; Grafana-native | Recommended |
| Observability: metrics | Prometheus + Grafana | Industry standard; scrapes Go runtime + Nuxt server metrics | Recommended |
| Observability: traces | OpenTelemetry SDK + Grafana Tempo | Distributed tracing across frontend → backend → database | Optional |
| Vulnerability scanning | Trivy | Open source; scans Docker images, Dockerfiles, and IaC for CVEs | Yes (CI) |
| Dependency audit (Go) | govulncheck | Official Go tool; checks `go.sum` against the Go vulnerability database | Yes (CI) |
| SAST (Go) | gosec | Detects security anti-patterns: hardcoded creds, unsafe SQL, weak crypto | Yes (CI) |
| Code quality (Go) | golangci-lint | Runs 50+ linters in one pass; configurable via `.golangci.yml` | Yes (CI) |
| YAML linting | yamllint | Validates blueprint YAML syntax and style before it reaches the binary | Yes (CI) |
| API documentation | swaggo/swag | Generates OpenAPI 3 spec from Go annotations in handlers | Optional |
| Database migration CI | `aethel migrate validate` | Dry-runs template rendering + SQL syntax check without touching DB | Recommended |
| Local K8s manifests | `kubeval` or `kubeconform` | Validates K8s YAML against API schemas before `kubectl apply` | Recommended |

---

## Tool Details & Usage

### Container Registry — GitHub Container Registry (ghcr.io)

**Why**: Free for public repositories; private packages included with GitHub Team/Enterprise.
No separate registry account needed — authentication uses `GITHUB_TOKEN` in Actions.

**Usage in CI/CD**:
```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

**Image naming convention**:
```
ghcr.io/<org>/aethel-core:<git-sha-7>
ghcr.io/<org>/aethel-view:<git-sha-7>
```

---

### Local Kubernetes — minikube / kind

**Why**: Test K8s manifests and Helm charts locally without a real cluster.

**minikube** (recommended for solo dev):
```bash
brew install minikube         # macOS
minikube start --driver=docker
kubectl config use-context minikube
make k8s-apply-dev
```

**kind** (recommended for CI):
```bash
go install sigs.k8s.io/kind@latest
kind create cluster --name aethel
kubectl config use-context kind-aethel
```

---

### Secret Management — HashiCorp Vault (production)

**Why**: Dynamic secrets (Vault generates DB credentials on-demand with TTLs), audit log of
all secret access, automatic rotation, no secret sprawl in environment variables.

**Install** (self-hosted on K8s):
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault --namespace vault --create-namespace \
  --set "server.dev.enabled=false"
```

**Usage with K8s**:
Install the External Secrets Operator and create an `ExternalSecret` resource that maps
Vault paths to K8s Secrets. The backend pod reads `aethel-core-secret` as normal.
```
vault kv put secret/aethel/backend \
  AETHEL_JWT_SECRET="$(openssl rand -base64 64)" \
  AETHEL_DB_DSN="postgres://..."
```

**Dev fallback**: Use `.env` file (copied from `.env.example`). Never commit `.env`.

---

### Observability: Logs — Loki + Promtail

**Why**: Loki is 10x cheaper than Elasticsearch for log storage; Promtail collects container
logs automatically by tailing K8s pod logs; native Grafana datasource.

**Install** (via Helm):
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack --namespace monitoring --create-namespace \
  --set grafana.enabled=true \
  --set promtail.enabled=true
```

**Backend integration**: Configure the Go backend to emit structured JSON logs to stdout.
Promtail picks them up automatically from the K8s pod's stdout stream.

---

### Observability: Metrics — Prometheus + Grafana

**Why**: Industry standard; Go has first-class support via `prometheus/client_golang`.
The `aethel-core` binary should expose a `/metrics` endpoint (Prometheus format).

**Install**:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

**Backend integration**:
```go
import "github.com/prometheus/client_golang/prometheus/promhttp"
http.Handle("/metrics", promhttp.Handler())
```

**Key dashboards to import** (Grafana dashboard IDs):
- Go runtime: `13181`
- Node.js (Nuxt SSR): `11159`
- PostgreSQL: `9628`

---

### Observability: Traces — OpenTelemetry + Grafana Tempo

**Why**: Distributed tracing shows the full request path from Nuxt SSR → Go API → PostgreSQL.
Grafana Tempo stores traces; OpenTelemetry is vendor-neutral.

**Install Tempo**:
```bash
helm install tempo grafana/tempo --namespace monitoring
```

**Backend integration**:
```go
import "go.opentelemetry.io/otel"
// Configure OTLP exporter pointing at Tempo collector endpoint
```

**Status**: Optional for Phase 2. Implement after core functionality is stable.

---

### Vulnerability Scanning — Trivy

**Why**: Single tool that scans Docker images, Dockerfiles, IaC files, and embedded secrets.
Free, open source, SARIF output integrates with GitHub Security tab.

**Install**:
```bash
brew install aquasecurity/trivy/trivy    # macOS
# or
go install github.com/aquasecurity/trivy/cmd/trivy@latest
```

**Local usage**:
```bash
# Scan the backend image
docker build -t aethel-core:local ./aethel-core
trivy image --severity CRITICAL,HIGH aethel-core:local

# Scan the repo filesystem (secrets, IaC misconfigs)
trivy fs --severity CRITICAL,HIGH,MEDIUM .
```

**CI**: See `.github/workflows/security.yml` — runs on every push to main and weekly.

---

### Dependency Audit (Go) — govulncheck

**Why**: Official Go tool from the Go team. Checks `go.sum` against
<https://vuln.go.dev> — more accurate than Trivy for Go-specific CVEs because it
understands which code paths actually call vulnerable functions.

**Install**:
```bash
go install golang.org/x/vuln/cmd/govulncheck@latest
```

**Usage**:
```bash
cd aethel-core
govulncheck ./...
```

**CI**: Runs as the `govulncheck` job in `.github/workflows/security.yml`.

---

### SAST (Go) — gosec

**Why**: Detects Go-specific security anti-patterns: SQL injection via `fmt.Sprintf`,
hardcoded credentials, use of weak RNG (`math/rand` instead of `crypto/rand`),
insecure TLS config, path traversal.

**Install**:
```bash
go install github.com/securego/gosec/v2/cmd/gosec@latest
```

**Usage**:
```bash
cd aethel-core
gosec ./...
```

**CI**: Runs as the `gosec` job in `.github/workflows/security.yml`, uploading SARIF.

**Configuration**: Create `aethel-core/.gosec.yaml` to suppress known false positives.

---

### Code Quality (Go) — golangci-lint

**Why**: Runs `errcheck`, `staticcheck`, `gosimple`, `ineffassign`, `unused`, `revive`,
and 40+ other linters in a single fast pass. Configurable via `.golangci.yml`.

**Install**:
```bash
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

**Usage**:
```bash
cd aethel-core
golangci-lint run ./...
```

**Recommended `.golangci.yml`** (create in `aethel-core/`):
```yaml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - revive
    - gosec
    - exhaustive
run:
  timeout: 5m
```

---

### YAML Linting — yamllint

**Why**: Catches syntax errors and style violations in blueprint YAML files before they
reach the binary. The project ships a `.yamllint` config tuned for blueprint alignment style.

**Install**:
```bash
pip install yamllint
```

**Usage**:
```bash
yamllint -c .yamllint blueprints/
```

**CI**: Runs as the `lint-yaml` job in `.github/workflows/ci.yml`.

---

### API Documentation — swaggo/swag (optional)

**Why**: Generates a full OpenAPI 3 specification from Go doc comments in HTTP handlers.
Produces a browsable Swagger UI for frontend developers and external integrators.

**Install**:
```bash
go install github.com/swaggo/swag/cmd/swag@latest
```

**Usage**:
```bash
cd aethel-core
swag init -g cmd/aethel/main.go --output docs/swagger
```

Then serve `docs/swagger/swagger.json` via a static file handler or host it on Swagger Hub.

**Status**: Optional — implement after the HTTP handlers are scaffolded in Phase 2.

---

### Database Migration CI — aethel migrate validate

**Why**: Runs Go template rendering (resolving `{{ T "tablename" }}` and `{{ .Schema }}`)
and checks SQL syntax via PostgreSQL's `pg_parse_query` (via `pgx`) without touching a
live database. Catches template typos and SQL errors in CI before they hit staging.

**Usage**:
```bash
# In CI (no database needed)
./aethel migrate validate

# Via Makefile
make migrate-validate
```

**CI**: Add a `validate-migrations` job to `ci.yml` once the Go CLI is scaffolded in Phase 2.

---

### K8s Manifest Validation — kubeconform (recommended)

**Why**: Validates Kubernetes YAML files against the official API schemas before `kubectl apply`.
Catches apiVersion typos, missing required fields, and deprecated API versions.

**Install**:
```bash
brew install kubeconform    # macOS
# or
go install github.com/yannh/kubeconform/cmd/kubeconform@latest
```

**Usage**:
```bash
kubeconform -strict -summary k8s/
```

**Recommended**: Add as a step in `ci.yml` once the K8s manifests stabilise.

---

## Architecture Decision Record — Tool Choices

| Decision | Rationale |
|---|---|
| GHCR over Docker Hub | No rate limits for org members; single auth via GITHUB_TOKEN |
| Loki over Elasticsearch | 10x lower storage cost; simpler ops; Grafana native |
| Trivy over Snyk | Open source; no SaaS account; scans both images and IaC |
| govulncheck over Nancy | Official Go team tool; understands reachability |
| gosec over CodeQL | Faster, Go-specific; CodeQL can be added later for deeper analysis |
| Vault over AWS Secrets Manager | No AWS vendor lock-in; works on any K8s cluster |
| kind in CI over minikube | Faster startup in GitHub Actions runners; Docker-in-Docker compatible |

---

*Last updated: 2026-05-26. Maintained by the Aethel platform team.*
