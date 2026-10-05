# This hook runs on the compute node, outside the new network namespace.
netns_failed() {
  echo "Failed to initialize Jupyter networking!" >&2
  pkill -TERM -P "${SCRIPT_PID}" || true
  clean_up 1
  exit 1
}
wait_file() {
  timeout 30 bash -c 'until [[ -s "$1" ]]; do sleep 0.1; done' _ "$1"
}

wait_file "${OOD_NETNS_DIR}/pid" || netns_failed
read -r ns_pid < "${OOD_NETNS_DIR}/pid"
slirp4netns --configure --mtu=65520 --disable-host-loopback \
  --api-socket "${OOD_NETNS_DIR}/slirp.sock" --ready-fd=4 --exit-fd=3 \
  "${ns_pid}" tap0 4>"${OOD_NETNS_DIR}/ready" \
  3< <(tail --pid="${ns_pid}" -f /dev/null) &
wait_file "${OOD_NETNS_DIR}/ready" || netns_failed

# Only the authenticated Jupyter web port is forwarded.
# slirp4netns replies but leaves the API socket open, so nc can only ever exit
# via its idle timeout; validate the reply body rather than nc's exit status.
hostfwd_reply=$(
  printf '{"execute":"add_hostfwd","arguments":{"proto":"tcp","host_addr":"0.0.0.0","host_port":%s,"guest_addr":"10.0.2.100","guest_port":%s}}' "${port}" "${port}" |
    nc -U --idle-timeout 2s "${OOD_NETNS_DIR}/slirp.sock" 2>/dev/null
)
if [[ "${hostfwd_reply}" != *'"return"'* ]]; then
  echo "slirp4netns add_hostfwd failed: ${hostfwd_reply:-no reply}" >&2
  netns_failed
fi

# Let the namespace's shell exec Jupyter after the network is ready.
timeout 5 bash -c 'echo ready > "$1"' _ "${OOD_NETNS_DIR}/start" || netns_failed

# A TCP probe would see slirp's listener before Jupyter itself is ready.
echo "Waiting for Jupyter Notebook server to respond on port ${port}..."
echo "TIMING - Starting wait at: $(date)"
if timeout 300 bash -c '
  until curl --noproxy "*" --fail --silent --output /dev/null \
    --connect-timeout 1 --max-time 2 "$1"; do sleep 1; done
' _ "http://127.0.0.1:${port}/node/${host}/${port}/"; then
  echo "Discovered Jupyter Notebook server responding on port ${port}!"
  echo "TIMING - Wait ended at: $(date)"
else
  echo "Timed out waiting for Jupyter Notebook server on port ${port}!"
  echo "TIMING - Wait ended at: $(date)"
  pkill -TERM -P "${SCRIPT_PID}" || true
  clean_up 1
fi
sleep 2
