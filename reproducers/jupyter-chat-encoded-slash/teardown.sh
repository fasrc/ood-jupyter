#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ood-jupyter-chat-encoded-slash}"

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
