#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash -n \
  "${SCRIPT_DIR}/entrypoint.sh" \
  "${SCRIPT_DIR}/run.sh" \
  "${SCRIPT_DIR}/probe.sh" \
  "${SCRIPT_DIR}/teardown.sh" \
  "${SCRIPT_DIR}/validate.sh"
python3 -m py_compile "${SCRIPT_DIR}/probe.py"

echo "Shell and Python syntax validation passed."

if [[ "${1:-}" == "--build" ]]; then
  docker build -t ood-jupyter-chat-encoded-slash-validate "${SCRIPT_DIR}"
  echo "Docker build validation passed."
fi
