#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ood-jupyter-chat-encoded-slash}"
MODE="default"

if [[ "${1:-}" == "--allow-encoded-slashes" ]]; then
  MODE="allow-encoded-slashes"
  shift
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--allow-encoded-slashes]" >&2
  exit 2
fi

exec docker exec "${CONTAINER_NAME}" python /opt/reproducer/probe.py --mode "${MODE}"
