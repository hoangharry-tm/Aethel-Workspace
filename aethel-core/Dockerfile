# =============================================================================
# NOTE: This Dockerfile expects go.mod and go.sum to exist in aethel-core/.
# Run `go mod init github.com/your-org/aethel-core` before building.
# The entry point is ./cmd/aethel — scaffold this in Phase 2.
# =============================================================================

# =============================================================================
# Stage 1: Builder
# =============================================================================
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# Copy module manifests first for layer caching
# (these files must exist; run `go mod init` and `go mod tidy` first)
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Copy blueprints into the build context so they can be embedded (if using go:embed)
# They are also mounted at runtime in dev; baked in for prod.
COPY ../blueprints ./blueprints

# Build the binary with dead-code elimination and no debug symbols
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /bin/aethel ./cmd/aethel

# =============================================================================
# Stage 2: Runtime (minimal distroless image)
# =============================================================================
FROM gcr.io/distroless/static-debian12 AS runtime

# Copy CA certificates from builder (needed for TLS to external services)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy the compiled binary
COPY --from=builder /bin/aethel /bin/aethel

# Copy blueprints (baked into image for production)
COPY --from=builder /build/blueprints /app/blueprints

WORKDIR /app

EXPOSE 8080

# Run as non-root (distroless nonroot user uid=65532)
USER nonroot:nonroot

CMD ["/bin/aethel", "serve"]
