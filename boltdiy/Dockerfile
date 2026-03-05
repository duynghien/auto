# Dockerfile.boltdiy
# Custom Dockerfile for bolt.diy self-hosted deployment
# Keeps wrangler available at runtime (needed for dockerstart command)
#
# Based on: https://github.com/stackblitz-labs/bolt.diy/blob/main/Dockerfile

# ---- build stage ----
FROM node:22-bookworm-slim AS build
WORKDIR /app

ENV HUSKY=0
ENV CI=true

RUN corepack enable && corepack prepare pnpm@9.15.9 --activate

RUN apt-get update && apt-get install -y --no-install-recommends git curl \
    && rm -rf /var/lib/apt/lists/*

ARG VITE_PUBLIC_APP_URL
ENV VITE_PUBLIC_APP_URL=${VITE_PUBLIC_APP_URL}

# Install all deps (including wrangler)
COPY bolt.diy-source/package.json bolt.diy-source/pnpm-lock.yaml* ./
RUN pnpm fetch

COPY bolt.diy-source/ .
RUN pnpm install --offline --frozen-lockfile

# Build the Remix/Cloudflare Pages app
RUN NODE_OPTIONS=--max-old-space-size=4096 pnpm run build

# ---- production runtime (keeps all deps so wrangler is available) ----
FROM build AS boltdiy-production
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5173
ENV HOST=0.0.0.0

ARG VITE_LOG_LEVEL=debug
ARG DEFAULT_NUM_CTX

ENV WRANGLER_SEND_METRICS=false \
    VITE_LOG_LEVEL=${VITE_LOG_LEVEL} \
    DEFAULT_NUM_CTX=${DEFAULT_NUM_CTX} \
    RUNNING_IN_DOCKER=true

# Pre-configure wrangler to disable metrics
RUN mkdir -p /root/.config/.wrangler && \
    echo '{"enabled":false}' > /root/.config/.wrangler/metrics.json

RUN chmod +x /app/bindings.sh

EXPOSE 5173

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=10 \
    CMD curl -fsS http://localhost:5173/ || exit 1

CMD ["pnpm", "run", "dockerstart"]
