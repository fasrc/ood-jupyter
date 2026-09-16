#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${IMAGE_NAME:-ood-jupyter-chat-encoded-slash-reproducer}"
CONTAINER_NAME="${CONTAINER_NAME:-ood-jupyter-chat-encoded-slash}"
PUBLISHED_PORT="${PUBLISHED_PORT:-8080}"
MODE="default"

if [[ "${1:-}" == "--allow-encoded-slashes" ]]; then
  MODE="allow-encoded-slashes"
  shift
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--allow-encoded-slashes]" >&2
  exit 2
fi

ALLOW_ENCODED_SLASHES=""
if [[ "${MODE}" == "allow-encoded-slashes" ]]; then
  ALLOW_ENCODED_SLASHES="NoDecode"
fi

docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${PUBLISHED_PORT}:80" \
  -e ALLOW_ENCODED_SLASHES="${ALLOW_ENCODED_SLASHES}" \
  "${IMAGE_NAME}" >/dev/null

echo "Started ${CONTAINER_NAME} on http://localhost:${PUBLISHED_PORT}/node/jupyter/8888/lab (${MODE})"
echo "Use ./probe.sh${MODE:+$([[ "${MODE}" == "allow-encoded-slashes" ]] && printf ' --allow-encoded-slashes')} to verify behavior."
