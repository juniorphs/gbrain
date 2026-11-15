FROM oven/bun:1.4.4-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache dependency layer
COPY package.json bun.lock bunfig.toml ./
COPY patches/ patches/
COPY scripts/postinstall.ts scripts/postinstall.ts
RUN bun install --frozen-lockfile

# Copy application source code
COPY . .

# Ensure admin dashboard assets and embedded files are built
RUN cd admin && bun install --frozen-lockfile && bun run build && cd .. && bun run build:admin-embedded

# Production environment variables
ENV NODE_ENV=production
ENV GBRAIN_HOME=/data
ENV PORT=3131
ENV GBRAIN_HTTP_TRUST_PROXY=1

RUN mkdir -p /data

EXPOSE 3131
VOLUME ["/data"]

COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
