#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOOTSTRAP_SERVERS="${CSA_BOOTSTRAP_SERVERS:-localhost:9092}"
SCHEMA_REGISTRY_URL="${CSA_SCHEMA_REGISTRY_URL:-http://localhost:7788/api/v1}"

log() {
  printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

check_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

check_cmd java
check_cmd mvn
check_cmd curl

log "Checking Schema Registry health at ${SCHEMA_REGISTRY_URL}/schemaregistry/schemas ..."
if ! curl -fsS "${SCHEMA_REGISTRY_URL}/schemaregistry/schemas" >/dev/null; then
  echo "Schema Registry is not reachable. Verify CSA is up (./start_csa.sh)." >&2
  exit 1
fi

log "Building project with Maven..."
(cd "$SCRIPT_DIR" && mvn -DskipTests clean package)

log "Running demo..."
(cd "$SCRIPT_DIR" && mvn -q exec:java)

log "Demo completed successfully."
log "Kafka broker configured as: ${BOOTSTRAP_SERVERS}"
