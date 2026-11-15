#!/bin/bash
set -e

# Data directory configuration
export GBRAIN_HOME="${GBRAIN_HOME:-/data}"
mkdir -p "$GBRAIN_HOME"

CONFIG_FILE="$GBRAIN_HOME/.gbrain/config.json"

# Check if brain configuration exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "[entrypoint] No brain config found at $CONFIG_FILE. Initializing..."
  
  INIT_ARGS=("init" "--non-interactive")
  
  if [ -n "$DATABASE_URL" ] || [ -n "$GBRAIN_DATABASE_URL" ]; then
    DB_URL="${DATABASE_URL:-$GBRAIN_DATABASE_URL}"
    echo "[entrypoint] Connecting to PostgreSQL database..."
    INIT_ARGS+=("--url" "$DB_URL")
  else
    echo "[entrypoint] Using embedded PGlite storage in $GBRAIN_HOME"
    INIT_ARGS+=("--pglite")
  fi

  # If no embedding key is present, skip embedding check so init doesn't block
  if [ -z "$OPENAI_API_KEY" ] && [ -z "$GEMINI_API_KEY" ] && [ -z "$VOYAGE_API_KEY" ]; then
    INIT_ARGS+=("--no-embedding")
  fi

  bun run src/cli.ts "${INIT_ARGS[@]}" || echo "[entrypoint] Initialization notice, continuing..."
fi

# Apply pending schema migrations
echo "[entrypoint] Checking and applying database migrations..."
bun run src/cli.ts apply-migrations --yes --no-autopilot-install || true

# Prepare HTTP server arguments
PORT="${PORT:-3131}"
SERVE_ARGS=("serve" "--http" "--port" "$PORT" "--bind" "0.0.0.0")

if [ -n "$PUBLIC_URL" ]; then
  SERVE_ARGS+=("--public-url" "$PUBLIC_URL")
fi

if [ -n "$GBRAIN_ADMIN_BOOTSTRAP_TOKEN" ]; then
  SERVE_ARGS+=("--suppress-bootstrap-token")
fi

if [ "$ENABLE_DCR" = "true" ] || [ "$ENABLE_DCR" = "1" ]; then
  SERVE_ARGS+=("--enable-dcr")
fi

echo "[entrypoint] Starting GBrain MCP HTTP Server on 0.0.0.0:$PORT..."
exec bun run src/cli.ts "${SERVE_ARGS[@]}"
