#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${WORKDIR:-$SCRIPT_DIR/.runtime}"
FLINK_VERSION="${FLINK_VERSION:-1.20.1}"
SCALA_SUFFIX="${SCALA_SUFFIX:-2.12}"
FLINK_BASE="flink-${FLINK_VERSION}"
FLINK_DIST="flink-${FLINK_VERSION}-bin-scala_${SCALA_SUFFIX}"
FLINK_HOME="${FLINK_HOME:-}"
FLINK_BIND_ADDRESS="${FLINK_BIND_ADDRESS:-0.0.0.0}"
FLINK_REST_HOST="${FLINK_REST_HOST:-127.0.0.1}"
FLINK_REST_PORT="${FLINK_REST_PORT:-8081}"
READINESS_TIMEOUT_SEC="${READINESS_TIMEOUT_SEC:-45}"
READINESS_INTERVAL_SEC="${READINESS_INTERVAL_SEC:-1}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERR] Missing required command: $cmd" >&2
    exit 1
  fi
}

resolve_flink_home() {
  if [[ -n "$FLINK_HOME" && -x "$FLINK_HOME/bin/start-cluster.sh" ]]; then
    return
  fi

  if [[ -x "$WORKDIR/$FLINK_BASE/bin/start-cluster.sh" ]]; then
    FLINK_HOME="$WORKDIR/$FLINK_BASE"
    return
  fi

  if [[ -x "$WORKDIR/$FLINK_DIST/bin/start-cluster.sh" ]]; then
    FLINK_HOME="$WORKDIR/$FLINK_DIST"
    return
  fi

  FLINK_HOME="$(find "$WORKDIR" -maxdepth 1 -mindepth 1 -type d -name "flink-${FLINK_VERSION}*" | head -n1 || true)"
  if [[ -n "$FLINK_HOME" && -x "$FLINK_HOME/bin/start-cluster.sh" ]]; then
    return
  fi

  echo "[ERR] start-cluster.sh not found under $WORKDIR" >&2
  echo "      Run run-windowing.sh once, or complete step 0 in README." >&2
  exit 1
}

set_in_section() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"

  sed -i "/^${section}:/,/^[^[:space:]#]/ s|^[[:space:]]*${key}:.*|  ${key}: ${value}|" "$file"
}

configure_network_binding() {
  local config_file="$FLINK_HOME/conf/config.yaml"

  if [[ ! -f "$config_file" ]]; then
    echo "[ERR] Missing config file: $config_file" >&2
    exit 1
  fi

  set_in_section "$config_file" "jobmanager" "bind-host" "$FLINK_BIND_ADDRESS"
  set_in_section "$config_file" "taskmanager" "bind-host" "$FLINK_BIND_ADDRESS"
  set_in_section "$config_file" "rest" "bind-address" "$FLINK_BIND_ADDRESS"
}

stop_existing_cluster() {
  (cd "$FLINK_HOME" && ./bin/stop-cluster.sh) || true
}

kill_stale_processes() {
  local pids

  pids="$(pgrep -f "${FLINK_HOME}/.*StandaloneSessionClusterEntrypoint|${FLINK_HOME}/.*TaskManagerRunner" || true)"
  if [[ -z "$pids" ]]; then
    return
  fi

  echo "[WARN] Found stale Flink processes for $FLINK_HOME: $pids"
  echo "[WARN] Stopping stale processes to ensure clean restart."
  kill $pids || true
  sleep 1
}

wait_for_readiness() {
  local url="http://${FLINK_REST_HOST}:${FLINK_REST_PORT}/overview"
  local deadline=$((SECONDS + READINESS_TIMEOUT_SEC))
  local latest_jm
  local latest_tm

  while (( SECONDS < deadline )); do
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      echo "Flink REST is ready: $url"
      return 0
    fi
    sleep "$READINESS_INTERVAL_SEC"
  done

  echo "[ERR] Flink REST did not become ready within ${READINESS_TIMEOUT_SEC}s: $url" >&2
  latest_jm="$(ls -1t "$FLINK_HOME"/log/flink-*-standalonesession-*-*.log 2>/dev/null | head -n1 || true)"
  latest_tm="$(ls -1t "$FLINK_HOME"/log/flink-*-taskexecutor-*-*.log 2>/dev/null | head -n1 || true)"

  if [[ -n "$latest_jm" ]]; then
    echo "[ERR] Last JobManager log tail: $latest_jm" >&2
    tail -n 60 "$latest_jm" >&2 || true
  fi
  if [[ -n "$latest_tm" ]]; then
    echo "[ERR] Last TaskManager log tail: $latest_tm" >&2
    tail -n 60 "$latest_tm" >&2 || true
  fi

  return 1
}

require_cmd curl
resolve_flink_home
configure_network_binding
stop_existing_cluster
kill_stale_processes

(cd "$FLINK_HOME" && ./bin/start-cluster.sh)
wait_for_readiness

echo "Started Flink cluster at $FLINK_HOME"
echo "REST/Web bind address: $FLINK_BIND_ADDRESS"
echo "Dashboard local: http://${FLINK_REST_HOST}:${FLINK_REST_PORT}"
