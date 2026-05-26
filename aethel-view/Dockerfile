# =============================================================================
# Stage 1: Builder
# =============================================================================
FROM node:20-alpine AS builder

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy package manifest first for layer caching
COPY package.json pnpm-lock.yaml ./

# Install all dependencies (including devDependencies needed for build)
RUN pnpm install --frozen-lockfile

# Copy the rest of the source
COPY . .

# Build the Nuxt application
RUN pnpm build

# =============================================================================
# Stage 2: Runtime
# =============================================================================
FROM node:20-alpine AS runtime

WORKDIR /app

# Copy built output from builder stage
COPY --from=builder /app/.output ./.output

# Run as non-root user
RUN addgroup -S aethel && adduser -S aethel -G aethel
USER aethel

EXPOSE 3000

ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000

CMD ["node", ".output/server/index.mjs"]
