# =============================================================================
# Aethel Workspace — Makefile
# Default target: help
# Run `make help` to see all available targets.
# =============================================================================

.DEFAULT_GOAL := help
.PHONY: help \
        dev dev-fe dev-be dev-db dev-down dev-reset \
        build build-fe build-be build-docker \
        test test-fe test-be test-e2e \
        lint lint-fe lint-be lint-yaml fmt \
        migrate-up migrate-down migrate-status migrate-validate db-shell db-dump \
        k8s-apply-dev k8s-apply-prod k8s-status \
        clean

# Directories
ROOT_DIR   := $(shell pwd)
VIEW_DIR   := $(ROOT_DIR)/aethel-view
CORE_DIR   := $(ROOT_DIR)/aethel-core
K8S_DIR    := $(ROOT_DIR)/k8s

# Docker Compose files
COMPOSE        := docker compose -f $(ROOT_DIR)/docker-compose.yml
COMPOSE_PROD   := $(COMPOSE) -f $(ROOT_DIR)/docker-compose.prod.yml

# K8s namespaces
NS_DEV  := aethel-workspace-dev
NS_PROD := aethel-workspace

# Binary
AETHEL_BIN := $(CORE_DIR)/bin/aethel

# Database defaults (override via .env or env vars)
DB_HOST     ?= localhost
DB_PORT     ?= 5432
DB_NAME     ?= aethel_dev
DB_USER     ?= aethel

# =============================================================================
## Development
# =============================================================================

## dev: Start all services via Docker Compose (postgres + backend + frontend)
dev:
	@$(COMPOSE) up

## dev-fe: Start only the Nuxt dev server (hot reload, no Docker)
dev-fe:
	@cd $(VIEW_DIR) && pnpm dev

## dev-be: Start only the Go backend (requires postgres running separately)
dev-be:
	@cd $(CORE_DIR) && go run ./cmd/aethel serve

## dev-db: Start only the postgres container
dev-db:
	@$(COMPOSE) up -d postgres

## dev-down: Stop and remove all dev containers (volumes are preserved)
dev-down:
	@$(COMPOSE) down

## dev-reset: Full reset — stop, delete volumes, start fresh database
dev-reset:
	@$(COMPOSE) down -v
	@$(COMPOSE) up -d postgres
	@echo "Fresh database started. Run 'make migrate-up' to apply migrations."

# =============================================================================
## Build
# =============================================================================

## build: Build frontend and backend
build: build-fe build-be

## build-fe: Build the Nuxt application (output → aethel-view/.output/)
build-fe:
	@echo "Building frontend..."
	@cd $(VIEW_DIR) && pnpm build

## build-be: Compile the Go backend binary (output → aethel-core/bin/aethel)
build-be:
	@echo "Building backend..."
	@mkdir -p $(CORE_DIR)/bin
	@cd $(CORE_DIR) && go build -ldflags="-w -s" -o $(AETHEL_BIN) ./cmd/aethel
	@echo "Binary: $(AETHEL_BIN)"

## build-docker: Build both Docker images locally (does not push)
build-docker:
	@echo "Building backend Docker image..."
	@docker build -t aethel-core:local $(CORE_DIR)
	@echo "Building frontend Docker image..."
	@docker build -t aethel-view:local $(VIEW_DIR)
	@echo "Images built: aethel-core:local, aethel-view:local"

# =============================================================================
## Testing
# =============================================================================

## test: Run all tests (frontend unit/component + backend)
test: test-fe test-be

## test-fe: Run frontend Vitest tests (unit + nuxt component)
test-fe:
	@cd $(VIEW_DIR) && pnpm test --run

## test-be: Run Go tests with race detector
test-be:
	@cd $(CORE_DIR) && go test -race ./...

## test-e2e: Run Playwright end-to-end tests (requires dev server running)
test-e2e:
	@cd $(VIEW_DIR) && pnpm test:e2e

# =============================================================================
## Linting / Formatting
# =============================================================================

## lint: Lint everything (frontend + backend + YAML blueprints)
lint: lint-fe lint-be lint-yaml

## lint-fe: ESLint the frontend
lint-fe:
	@cd $(VIEW_DIR) && pnpm exec eslint .

## lint-be: golangci-lint the backend
lint-be:
	@cd $(CORE_DIR) && golangci-lint run ./...

## lint-yaml: yamllint on blueprints/
lint-yaml:
	@yamllint -c $(ROOT_DIR)/.yamllint $(ROOT_DIR)/blueprints/

## fmt: Format Go code (gofmt) and frontend code (prettier via pnpm)
fmt:
	@echo "Formatting Go code..."
	@cd $(CORE_DIR) && gofmt -w .
	@echo "Formatting frontend code..."
	@cd $(VIEW_DIR) && pnpm exec prettier --write .

# =============================================================================
## Database
# =============================================================================

## migrate-up: Apply all pending migrations (via aethel migrate up)
migrate-up:
	@$(AETHEL_BIN) migrate up

## migrate-down: Roll back the last applied migration
migrate-down:
	@$(AETHEL_BIN) migrate down --steps 1

## migrate-status: Show applied and pending migrations
migrate-status:
	@$(AETHEL_BIN) migrate status

## migrate-validate: Dry-run template rendering — validates SQL syntax without applying
migrate-validate:
	@$(AETHEL_BIN) migrate validate

## db-shell: Open a psql shell into the dev database
db-shell:
	@PGPASSWORD=$${POSTGRES_PASSWORD:-changeme_dev_only} \
		psql -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) -d $(DB_NAME)

## db-dump: Dump the dev database to /tmp/aethel-dump.sql
db-dump:
	@DUMP_FILE="/tmp/aethel-dump-$$(date +%Y%m%d_%H%M%S).sql"; \
	echo "Dumping database to $$DUMP_FILE..."; \
	PGPASSWORD=$${POSTGRES_PASSWORD:-changeme_dev_only} \
		pg_dump -h $(DB_HOST) -p $(DB_PORT) -U $(DB_USER) $(DB_NAME) > "$$DUMP_FILE"; \
	echo "Done: $$DUMP_FILE"

# =============================================================================
## Kubernetes
# =============================================================================

## k8s-apply-dev: Apply all k8s manifests to the dev namespace
k8s-apply-dev:
	@kubectl apply -f $(K8S_DIR)/namespace.yaml 2>/dev/null || true
	@kubectl apply -f $(K8S_DIR)/ --recursive -n $(NS_DEV)

## k8s-apply-prod: Apply all k8s manifests to the production namespace
k8s-apply-prod:
	@kubectl apply -f $(K8S_DIR)/namespace.yaml 2>/dev/null || true
	@kubectl apply -f $(K8S_DIR)/ --recursive -n $(NS_PROD)

## k8s-status: Show all resources in the production namespace
k8s-status:
	@kubectl get all -n $(NS_PROD)

# =============================================================================
## Utilities
# =============================================================================

## clean: Remove build artifacts, .nuxt cache, and Go build cache
clean:
	@echo "Cleaning frontend build artifacts..."
	@rm -rf $(VIEW_DIR)/.nuxt $(VIEW_DIR)/.output $(VIEW_DIR)/dist
	@echo "Cleaning backend build artifacts..."
	@rm -rf $(CORE_DIR)/bin
	@echo "Clearing Go build cache..."
	@go clean -cache 2>/dev/null || true
	@echo "Clean complete."

# =============================================================================
## Help
# =============================================================================

## help: Print this help message (default target)
help:
	@echo ""
	@echo "Aethel Workspace — available make targets:"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //' | \
		awk -F': ' '{ printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2 }'
	@echo ""
