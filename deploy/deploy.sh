#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.prod.yaml"

if [[ -f deploy/production.env ]]; then
  export $(grep -v '^#' deploy/production.env | xargs -0 2>/dev/null || grep -v '^#' deploy/production.env | xargs)
fi

if [[ -n "${GHCR_USER:-}" && -n "${GHCR_TOKEN:-}" ]]; then
  echo "Logging into GHCR..."
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
fi

echo "Pulling latest images..."
docker compose -f "$COMPOSE_FILE" pull

echo "Starting services..."
docker compose -f "$COMPOSE_FILE" up -d

backend_container=$(docker compose -f "$COMPOSE_FILE" ps -q backend)

echo "Waiting for backend to be healthy..."
for i in {1..30}; do
  echo "Attempt $i/30"
  if docker exec "$backend_container" curl -sf http://localhost:3000/health >/dev/null 2>&1; then
    echo "Backend is healthy"
    break
  fi
  sleep 2
done

if ! docker exec "$backend_container" curl -sf http://localhost:3000/health >/dev/null 2>&1; then
  echo "Backend did not become healthy in time"
  echo "Backend logs:" && docker compose -f "$COMPOSE_FILE" logs backend | tail -100
  exit 1
fi

echo "Deployment completed successfully"
