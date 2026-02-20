#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${WORKDIR:-$SCRIPT_DIR/.runtime}"
FLINK_VERSION="${FLINK_VERSION:-1.20.1}"
SCALA_SUFFIX="${SCALA_SUFFIX:-2.12}"
FLINK_BASE="flink-${FLINK_VERSION}"
FLINK_DIST="flink-${FLINK_VERSION}-bin-scala_${SCALA_SUFFIX}"
FLINK_HOME="${FLINK_HOME:-}"

if [[ -z "$FLINK_HOME" ]]; then
  if [[ -x "$WORKDIR/$FLINK_BASE/bin/stop-cluster.sh" ]]; then
    FLINK_HOME="$WORKDIR/$FLINK_BASE"
  elif [[ -x "$WORKDIR/$FLINK_DIST/bin/stop-cluster.sh" ]]; then
    FLINK_HOME="$WORKDIR/$FLINK_DIST"
  else
    FLINK_HOME="$(find "$WORKDIR" -maxdepth 1 -mindepth 1 -type d -name "flink-${FLINK_VERSION}*" | head -n1 || true)"
  fi
fi

if [[ -z "$FLINK_HOME" || ! -x "$FLINK_HOME/bin/stop-cluster.sh" ]]; then
  echo "[ERR] stop-cluster.sh not found at $FLINK_HOME/bin/stop-cluster.sh" >&2
  echo "      Run run-wordcount.sh at least once, or set FLINK_HOME explicitly." >&2
  exit 1
fi

(cd "$FLINK_HOME" && ./bin/stop-cluster.sh)
echo "Stopped Flink cluster at $FLINK_HOME"
