#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-/node/jupyter/8888/}"
JUPYTER_PORT="${JUPYTER_PORT:-8888}"
ALLOW_ENCODED_SLASHES="${ALLOW_ENCODED_SLASHES:-}"

if [[ "${BASE_URL}" != */ ]]; then
  BASE_URL="${BASE_URL}/"
fi

apache_allow_directive="# Apache default: AllowEncodedSlashes Off"
if [[ -n "${ALLOW_ENCODED_SLASHES}" ]]; then
  apache_allow_directive="AllowEncodedSlashes ${ALLOW_ENCODED_SLASHES}"
fi

cat > /etc/apache2/sites-available/000-default.conf <<APACHECONF
ServerName localhost

<VirtualHost *:80>
    ServerName localhost
    ProxyRequests Off
    ProxyPreserveHost On
    ${apache_allow_directive}

    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"

    ProxyPass "${BASE_URL}api/chat/ws/"  "ws://127.0.0.1:${JUPYTER_PORT}${BASE_URL}api/chat/ws/" retry=0 nocanon
    ProxyPassReverse "${BASE_URL}api/chat/ws/"  "ws://127.0.0.1:${JUPYTER_PORT}${BASE_URL}api/chat/ws/"

    ProxyPass "${BASE_URL}" "http://127.0.0.1:${JUPYTER_PORT}${BASE_URL}" retry=0
    ProxyPassReverse "${BASE_URL}" "http://127.0.0.1:${JUPYTER_PORT}${BASE_URL}"

    ErrorLog /proc/self/fd/2
    CustomLog /proc/self/fd/1 combined
</VirtualHost>
APACHECONF

apache2ctl -t

jupyter lab \
  --allow-root \
  --config=/opt/reproducer/jupyter/jupyter_server_config.py \
  --ServerApp.base_url="${BASE_URL}" \
  --ServerApp.port="${JUPYTER_PORT}" \
  --ServerApp.root_dir=/work \
  >/tmp/jupyter.log 2>&1 &

JUPYTER_PID=$!
export JUPYTER_PID

cleanup() {
  if kill -0 "${JUPYTER_PID}" >/dev/null 2>&1; then
    kill "${JUPYTER_PID}" >/dev/null 2>&1 || true
    wait "${JUPYTER_PID}" || true
  fi
}
trap cleanup EXIT

for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${JUPYTER_PORT}${BASE_URL}api" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "http://127.0.0.1:${JUPYTER_PORT}${BASE_URL}api" >/dev/null 2>&1; then
  echo "Jupyter failed to become ready" >&2
  cat /tmp/jupyter.log >&2 || true
  exit 1
fi

echo "Jupyter ready at http://127.0.0.1:${JUPYTER_PORT}${BASE_URL}lab" >&2
echo "Apache mode: ${ALLOW_ENCODED_SLASHES:-default-off}" >&2

exec apache2ctl -D FOREGROUND
