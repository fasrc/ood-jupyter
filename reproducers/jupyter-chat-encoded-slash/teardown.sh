#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-ood-jupyter-chat-encoded-slash}"

docker rm -f "${CONTAINER_NAME}"
