# Multi-arch Scrapling Docker image
# Supports: linux/amd64 (VPS), linux/arm64 (Raspberry Pi), darwin/arm64 (macOS Apple Silicon via Rosetta)
FROM python:3.12-slim-bookworm

# Install system dependencies
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Install uv (fast Python package manager used by Scrapling)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# Install git to clone the repository
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone Scrapling from GitHub
RUN git clone --depth=1 https://github.com/D4Vinci/Scrapling.git /app

# Copy dependency file first for better layer caching - already present from clone

# Install Python dependencies (all extras: fetchers + ai + shell)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --no-install-project --all-extras --compile-bytecode

# Install Playwright browser + system deps + finalize project install
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    uv run playwright install-deps chromium && \
    uv run playwright install chromium && \
    uv sync --all-extras --compile-bytecode && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Expose MCP server port
EXPOSE 8000

# Create output directory for scraped content
RUN mkdir -p /data
WORKDIR /data

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD uv run --project /app scrapling --help > /dev/null 2>&1 || exit 1

# Entrypoint
ENTRYPOINT ["uv", "run", "--project", "/app", "scrapling"]
CMD ["--help"]
