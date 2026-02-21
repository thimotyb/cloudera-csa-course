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

resolve_flink_home
configure_network_binding
stop_existing_cluster
kill_stale_processes

(cd "$FLINK_HOME" && ./bin/start-cluster.sh)

echo "Started Flink cluster at $FLINK_HOME"
echo "REST/Web bind address: $FLINK_BIND_ADDRESS"
echo "Dashboard local: http://127.0.0.1:8081"
