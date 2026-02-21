#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB_DIR="${JOB_DIR:-$SCRIPT_DIR/windowing-job}"
WORKDIR="${WORKDIR:-$SCRIPT_DIR/.runtime}"
FLINK_VERSION="${FLINK_VERSION:-1.20.1}"
SCALA_SUFFIX="${SCALA_SUFFIX:-2.12}"
FLINK_BASE="flink-${FLINK_VERSION}"
FLINK_DIST="flink-${FLINK_VERSION}-bin-scala_${SCALA_SUFFIX}"
FLINK_TGZ="${FLINK_DIST}.tgz"
FLINK_HOME="${FLINK_HOME:-}"
MAIN_CLASS="org.pd.streaming.window.example.TumblingWindowExample"
WINDOW_MODE="${WINDOW_MODE:-time}"
TIME_WINDOW_SEC="${TIME_WINDOW_SEC:-5}"
COUNT_WINDOW_SIZE="${COUNT_WINDOW_SIZE:-4}"
SOURCE_PERIOD_MS="${SOURCE_PERIOD_MS:-1000}"
WAIT_SECONDS="${WAIT_SECONDS:-10}"
TAIL_LINES="${TAIL_LINES:-120}"
KEEP_JOB_RUNNING="${KEEP_JOB_RUNNING:-false}"
KEEP_CLUSTER_RUNNING="${KEEP_CLUSTER_RUNNING:-false}"
FLINK_BIND_ADDRESS="${FLINK_BIND_ADDRESS:-0.0.0.0}"

CLUSTER_STARTED=false
CLUSTER_STOPPED=false
JOB_ID=""
JOB_CANCELLED=false

log() {
  printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERR] Missing required command: $cmd" >&2
    exit 1
  fi
}

java_major() {
  java -version 2>&1 | awk -F '[".]' '/version/ {print $2; exit}'
}

require_java_21() {
  local major
  major="$(java_major)"
  if [[ -z "$major" || ! "$major" =~ ^[0-9]+$ ]]; then
    echo "[ERR] Unable to detect Java version" >&2
    exit 1
  fi
  if (( major < 21 )); then
    echo "[ERR] Detected Java ${major}. This demo requires JDK 21+." >&2
    echo "      Set JAVA_HOME to a JDK 21 installation and retry." >&2
    exit 1
  fi
  log "Java version OK (major=${major})"
}

download_flink() {
  local tgz_path="$WORKDIR/$FLINK_TGZ"
  local urls=(
    "https://dlcdn.apache.org/flink/flink-${FLINK_VERSION}/${FLINK_TGZ}"
    "https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/${FLINK_TGZ}"
  )

  if [[ -f "$tgz_path" ]]; then
    log "Found existing archive: $tgz_path"
    return
  fi

  log "Downloading Flink archive: $FLINK_TGZ"
  for url in "${urls[@]}"; do
    log "Trying ${url}"
    if curl -fL "$url" -o "$tgz_path"; then
      log "Download completed"
      return
    fi
  done

  echo "[ERR] Unable to download ${FLINK_TGZ}" >&2
  exit 1
}

extract_flink() {
  if [[ -n "$FLINK_HOME" && -x "$FLINK_HOME/bin/flink" ]]; then
    log "Flink already extracted: $FLINK_HOME"
    return
  fi

  if [[ -x "$WORKDIR/$FLINK_BASE/bin/flink" ]]; then
    log "Flink already extracted: $WORKDIR/$FLINK_BASE"
    return
  fi

  if [[ -x "$WORKDIR/$FLINK_DIST/bin/flink" ]]; then
    log "Flink already extracted: $WORKDIR/$FLINK_DIST"
    return
  fi

  if find "$WORKDIR" -maxdepth 1 -mindepth 1 -type d -name "flink-${FLINK_VERSION}*" | head -n1 | grep -q .; then
    log "Flink extraction directory already present in $WORKDIR"
    return
  fi

  log "Extracting Flink into $WORKDIR"
  tar -xf "$WORKDIR/$FLINK_TGZ" -C "$WORKDIR"
}

resolve_flink_home() {
  local candidates=(
    "$WORKDIR/$FLINK_BASE"
    "$WORKDIR/$FLINK_DIST"
  )
  local path

  if [[ -n "$FLINK_HOME" ]]; then
    if [[ ! -x "$FLINK_HOME/bin/flink" ]]; then
      echo "[ERR] FLINK_HOME is set but invalid: $FLINK_HOME" >&2
      exit 1
    fi
    log "Using FLINK_HOME from environment: $FLINK_HOME"
    return
  fi

  for path in "${candidates[@]}"; do
    if [[ -x "$path/bin/flink" ]]; then
      FLINK_HOME="$path"
      log "Resolved FLINK_HOME: $FLINK_HOME"
      return
    fi
  done

  path=$(find "$WORKDIR" -maxdepth 1 -mindepth 1 -type d -name "flink-${FLINK_VERSION}*" | head -n1 || true)
  if [[ -n "$path" && -x "$path/bin/flink" ]]; then
    FLINK_HOME="$path"
    log "Resolved FLINK_HOME from extracted directories: $FLINK_HOME"
    return
  fi

  echo "[ERR] Extraction completed but no valid Flink home found in $WORKDIR" >&2
  exit 1
}

build_windowing_jar() {
  if [[ ! -f "$JOB_DIR/pom.xml" ]]; then
    echo "[ERR] Missing Maven project at $JOB_DIR" >&2
    exit 1
  fi

  log "Building windowing tutorial jar with Maven"
  mvn -f "$JOB_DIR/pom.xml" -DskipTests clean package

  JAR_PATH="$(ls -1 "$JOB_DIR"/target/*.jar | grep -v 'sources\|javadoc\|original' | head -n1 || true)"
  if [[ -z "$JAR_PATH" || ! -f "$JAR_PATH" ]]; then
    echo "[ERR] Build completed but jar not found under $JOB_DIR/target" >&2
    exit 1
  fi

  log "Built jar: $JAR_PATH"
}

start_cluster() {
  log "Starting local Flink cluster"
  FLINK_HOME="$FLINK_HOME" FLINK_BIND_ADDRESS="$FLINK_BIND_ADDRESS" "$SCRIPT_DIR/start-cluster.sh"
  CLUSTER_STARTED=true
  log "Flink Dashboard: http://localhost:8081"
}

run_job_detached() {
  local output

  log "Submitting job in detached mode (mode=${WINDOW_MODE})"
  output="$(cd "$FLINK_HOME" && ./bin/flink run -d \
    -c "$MAIN_CLASS" \
    "$JAR_PATH" \
    --mode "$WINDOW_MODE" \
    --time-window-sec "$TIME_WINDOW_SEC" \
    --count-window-size "$COUNT_WINDOW_SIZE" \
    --source-period-ms "$SOURCE_PERIOD_MS" 2>&1)"

  printf '%s\n' "$output"

  JOB_ID="$(printf '%s\n' "$output" | grep -Eo '[0-9a-f]{32}' | tail -n1 || true)"
  if [[ -z "$JOB_ID" ]]; then
    log "Job ID not found in submit output; continuing without auto-cancel"
    return
  fi

  log "Submitted JobID: $JOB_ID"
}

list_jobs() {
  log "Current jobs"
  (cd "$FLINK_HOME" && ./bin/flink list)
}

show_taskexecutor_log_tail() {
  local task_log
  task_log=$(ls -1t "$FLINK_HOME"/log/flink-*-taskexecutor-*.out 2>/dev/null | head -n1 || true)

  if [[ -z "$task_log" ]]; then
    log "TaskExecutor log not found yet in $FLINK_HOME/log"
    return
  fi

  log "Tail ${TAIL_LINES} lines from: $task_log"
  tail -n "$TAIL_LINES" "$task_log"
}

cancel_job() {
  if [[ "$KEEP_JOB_RUNNING" == "true" ]]; then
    log "KEEP_JOB_RUNNING=true, leaving job running"
    return
  fi

  if [[ -z "$JOB_ID" ]]; then
    log "No JobID available for auto-cancel"
    return
  fi

  log "Cancelling job $JOB_ID"
  (cd "$FLINK_HOME" && ./bin/flink cancel "$JOB_ID")
  JOB_CANCELLED=true
}

stop_cluster() {
  if [[ "$KEEP_CLUSTER_RUNNING" == "true" ]]; then
    log "KEEP_CLUSTER_RUNNING=true, leaving cluster up"
    log "Stop manually with: $SCRIPT_DIR/stop-cluster.sh"
    return
  fi

  log "Stopping local Flink cluster"
  (cd "$FLINK_HOME" && ./bin/stop-cluster.sh)
  CLUSTER_STOPPED=true
}

cleanup() {
  local rc="$1"

  if [[ "$rc" -ne 0 ]]; then
    echo "[ERR] run-windowing.sh failed (exit code=$rc)" >&2
  fi

  if [[ "$KEEP_JOB_RUNNING" != "true" && -n "$JOB_ID" && "$JOB_CANCELLED" != "true" ]]; then
    cancel_job || true
  fi

  if [[ "$KEEP_CLUSTER_RUNNING" != "true" && "$CLUSTER_STARTED" == "true" && "$CLUSTER_STOPPED" != "true" ]]; then
    stop_cluster || true
  fi

  if [[ "$rc" -eq 0 ]]; then
    log "Done"
  fi
}

trap 'cleanup "$?"' EXIT

require_cmd java
require_cmd curl
require_cmd tar
require_cmd mvn

mkdir -p "$WORKDIR"

require_java_21
download_flink
extract_flink
resolve_flink_home
build_windowing_jar
start_cluster
run_job_detached

log "Waiting ${WAIT_SECONDS}s to accumulate window output"
sleep "$WAIT_SECONDS"

list_jobs
show_taskexecutor_log_tail
cancel_job
stop_cluster
