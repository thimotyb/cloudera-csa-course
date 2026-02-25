#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

resolve_running_container() {
  local explicit_name="$1"
  local pattern="$2"

  if [[ -n "$explicit_name" ]] && docker ps --format '{{.Names}}' | grep -qx "$explicit_name"; then
    echo "$explicit_name"
    return 0
  fi

  docker ps --format '{{.Names}}' | grep -E "$pattern" | head -n1 || true
}

KAFKA_CONTAINER="${KAFKA_CONTAINER:-$(resolve_running_container "" '(^|[-_])kafka[-_]1$')}"
CONNECT_CONTAINER="${CONNECT_CONTAINER:-$(resolve_running_container "" '(^|[-_])kafka-connect[-_]1$')}"

if [[ -z "$KAFKA_CONTAINER" || -z "$CONNECT_CONTAINER" ]]; then
  echo "[ERR] Container richiesti non trovati (kafka/kafka-connect)."
  echo "      Avvia prima CSA CE (es. ./start_csa.sh)"
  echo "      Container attivi:"
  docker ps --format '      - {{.Names}}'
  exit 1
fi

CSA_DOCKER_NETWORK="${CSA_DOCKER_NETWORK:-$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$CONNECT_CONTAINER" | head -n1 | tr -d '[:space:]')}"
if [[ -z "$CSA_DOCKER_NETWORK" ]]; then
  echo "[ERR] Impossibile rilevare la rete Docker del container $CONNECT_CONTAINER"
  exit 1
fi
if ! docker network ls --format '{{.Name}}' | grep -q "^${CSA_DOCKER_NETWORK}$"; then
  echo "[ERR] Rete Docker ${CSA_DOCKER_NETWORK} non trovata"
  exit 1
fi
export CSA_DOCKER_NETWORK
echo "[INFO] Uso rete Docker: ${CSA_DOCKER_NETWORK}"
echo "[INFO] Kafka container: ${KAFKA_CONTAINER}"
echo "[INFO] Kafka Connect container: ${CONNECT_CONTAINER}"

compose_cmd=""
if docker compose version >/dev/null 2>&1; then
  compose_cmd="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  compose_cmd="docker-compose"
else
  echo "[ERR] Docker Compose non trovato (serve 'docker compose' o 'docker-compose')"
  exit 1
fi

echo "[INFO] Avvio MySQL CDC demo"
${compose_cmd} -f "$PROJECT_DIR/docker-compose.yml" up -d

echo "[INFO] Attendo MySQL healthy"
for i in $(seq 1 60); do
  status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}unknown{{end}}' csa-mysql-source-1 2>/dev/null || true)
  if [[ "$status" == "healthy" ]]; then
    echo "[OK] MySQL pronto"
    break
  fi
  sleep 2
  if [[ "$i" == "60" ]]; then
    echo "[ERR] Timeout attesa MySQL healthy"
    exit 1
  fi
done

"$SCRIPT_DIR/install-mysql-jdbc-driver.sh"
"$SCRIPT_DIR/create-mysql-source-connector.sh"

echo "[OK] Demo pronta"
echo "      1) Inserisci record: $SCRIPT_DIR/insert-demo-records.sh"
echo "      2) Leggi topic:      $SCRIPT_DIR/consume-topic.sh"
