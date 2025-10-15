# syntax=docker/dockerfile:1
# 
# Root Dockerfile for the complete Svix Webhooks project
# This builds the main Svix server, bridge, and CLI components
#
# Build with: docker build -t svix-complete .
# Run with: docker run -p 8071:8071 svix-complete

# Base image for planner and build - keep in sync with server/Dockerfile
FROM docker.io/rust:1.89-slim-trixie AS chef
RUN cargo install cargo-chef
WORKDIR /app

# Build plan environment
FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# Build environment
FROM chef AS build

SHELL ["/bin/bash", "-eux", "-o", "pipefail", "-c"]

# Install build dependencies
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked --mount=target=/var/cache/apt,type=cache,sharing=locked <<EOF
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -q
    apt-get install -y \
        build-essential=12.* \
        checkinstall=1.* \
        zlib1g-dev=1:* \
        pkg-config=1.8.* \
        libssl-dev=* \
        curl=8.* \
        cmake=3.* \
        --no-install-recommends
EOF

# Create app user
RUN <<EOF
    mkdir -p /app
    useradd appuser
    chown -R appuser: /app
    mkdir -p /home/appuser
    chown -R appuser: /home/appuser
EOF

COPY --from=planner /app/recipe.json recipe.json

# Build dependencies - this is the caching Docker layer
RUN cargo chef cook --release --recipe-path recipe.json

# Build all components
COPY . .

# Build Svix Server
RUN cargo build --release --package svix-server --bin svix-server --frozen

# Build Svix Bridge
WORKDIR /app/bridge
RUN cargo build --release --frozen

# Build Svix CLI
WORKDIR /app/svix-cli
RUN cargo build --release --frozen

# Production image
FROM docker.io/debian:trixie-slim AS prod

SHELL ["/bin/bash", "-eux", "-o", "pipefail", "-c"]

# Create app user
RUN <<EOF
    mkdir -p /app
    useradd appuser
    chown -R appuser: /app
    mkdir -p /home/appuser
    chown -R appuser: /home/appuser
EOF

# Install runtime dependencies
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked --mount=target=/var/cache/apt,type=cache,sharing=locked <<EOF
    apt-get update -q
    apt-get install -y \
        ca-certificates=20250419 \
        libssl3t64=3.* \
        curl=8.* \
        jq=1.* \
        --no-install-recommends
    update-ca-certificates
EOF

# Copy binaries
COPY --chown=root:root --chmod=755 --from=build /app/target/release/svix-server /usr/local/bin/svix-server
COPY --chown=root:root --chmod=755 --from=build /app/bridge/target/release/svix-bridge /usr/local/bin/svix-bridge
COPY --chown=root:root --chmod=755 --from=build /app/svix-cli/target/release/svix /usr/local/bin/svix

# Copy launch scripts
COPY --chown=root:root --chmod=755 ./server/scripts/launch-svix-server /usr/local/bin/launch-svix-server
COPY --chown=root:root --chmod=755 ./bridge/scripts/check-deps.sh /usr/local/bin/check-deps.sh

# Create startup script
RUN <<EOF
cat > /usr/local/bin/startup.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

echo "Svix Webhooks - Complete Docker Image"
echo "Available commands:"
echo "  svix-server - Main Svix server"
echo "  svix-bridge - Svix bridge"
echo "  svix        - Svix CLI"
echo ""

# Default to running the server
if [ "\${1:-}" = "" ]; then
    echo "Starting Svix Server..."
    exec /usr/local/bin/launch-svix-server
else
    echo "Running command: \$*"
    exec "\$@"
fi
SCRIPT
chmod +x /usr/local/bin/startup.sh
EOF

# Switch to app user
USER appuser

# Expose ports
EXPOSE 8071 5000

# Set working directory
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD svix-server healthcheck http://localhost:8071 || exit 1

# Default command
CMD ["/usr/local/bin/startup.sh"]