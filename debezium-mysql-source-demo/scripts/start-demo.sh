#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

required_containers=(cloudera-kafka-1 cloudera-kafka-connect-1)
for c in "${required_containers[@]}"; do
  if ! docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
    echo "[ERR] Container richiesto non in esecuzione: $c"
    echo "      Avvia prima CSA CE (es. ./start_csa.sh)"
    exit 1
  fi
done

CSA_DOCKER_NETWORK="${CSA_DOCKER_NETWORK:-$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' cloudera-kafka-connect-1 | head -n1 | tr -d '[:space:]')}"
if [[ -z "$CSA_DOCKER_NETWORK" ]]; then
  echo "[ERR] Impossibile rilevare la rete Docker del container cloudera-kafka-connect-1"
  exit 1
fi
if ! docker network ls --format '{{.Name}}' | grep -q "^${CSA_DOCKER_NETWORK}$"; then
  echo "[ERR] Rete Docker ${CSA_DOCKER_NETWORK} non trovata"
  exit 1
fi
export CSA_DOCKER_NETWORK
echo "[INFO] Uso rete Docker: ${CSA_DOCKER_NETWORK}"

echo "[INFO] Avvio MySQL CDC demo"
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d

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
