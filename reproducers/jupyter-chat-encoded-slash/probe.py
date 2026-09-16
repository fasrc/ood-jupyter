#!/usr/bin/env python3
import argparse
import base64
import json
import secrets
import socket
import sys
import time
from dataclasses import dataclass
from urllib.parse import urlparse
from urllib.request import urlopen


@dataclass
class ProbeResult:
    label: str
    path: str
    status: int
    server: str
    upgrade: str
    frame_type: str = ""
    frame_payload: str = ""
    frame_excerpt: str = ""


def wait_for_http(url: str, timeout: float = 60.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urlopen(url, timeout=5) as response:
                if response.status == 200:
                    return
        except Exception:
            time.sleep(1)
    raise RuntimeError(f"Timed out waiting for {url}")


def recv_until(sock: socket.socket, marker: bytes) -> bytes:
    data = b""
    while marker not in data:
        chunk = sock.recv(4096)
        if not chunk:
            break
        data += chunk
    return data


def recv_exact(sock: socket.socket, size: int, initial: bytes = b"") -> bytes:
    data = initial
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise RuntimeError(f"Expected {size} bytes but received only {len(data)}")
        data += chunk
    return data


def read_frame(sock: socket.socket) -> tuple[str, str]:
    sock.settimeout(5)
    header = recv_exact(sock, 2)
    first, second = header
    opcode = first & 0x0F
    masked = bool(second & 0x80)
    length = second & 0x7F
    if length == 126:
        length = int.from_bytes(recv_exact(sock, 2), "big")
    elif length == 127:
        length = int.from_bytes(recv_exact(sock, 8), "big")
    mask = recv_exact(sock, 4) if masked else b""
    payload = recv_exact(sock, length) if length else b""
    if masked:
        payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    text = payload.decode("utf-8", errors="replace")
    frame_type = {1: "text", 8: "close", 9: "ping", 10: "pong"}.get(opcode, f"opcode-{opcode}")
    return frame_type, text


def websocket_probe(base_url: str, path: str, label: str) -> ProbeResult:
    parsed = urlparse(base_url)
    if parsed.scheme == "https":
        raise ValueError("https base URLs are not supported by this probe; use an http URL through Apache")
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    request_path = parsed.path.rstrip("/") + path
    ws_key = base64.b64encode(secrets.token_bytes(16)).decode("ascii")

    with socket.create_connection((host, port), timeout=10) as sock:
        sock.settimeout(10)
        request = (
            f"GET {request_path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Connection: Upgrade\r\n"
            "Upgrade: websocket\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            f"Sec-WebSocket-Key: {ws_key}\r\n"
            f"Origin: {parsed.scheme}://{host}:{port}\r\n"
            "\r\n"
        )
        sock.sendall(request.encode("ascii"))
        response = recv_until(sock, b"\r\n\r\n")
        if b"\r\n\r\n" not in response:
            raise RuntimeError(f"Incomplete HTTP response for {label}")
        raw_headers, _ = response.split(b"\r\n\r\n", 1)
        lines = raw_headers.decode("iso-8859-1").split("\r\n")
        status = int(lines[0].split()[1])
        headers = {}
        for line in lines[1:]:
            if ":" in line:
                key, value = line.split(":", 1)
                headers[key.strip().lower()] = value.strip()
        result = ProbeResult(
            label=label,
            path=request_path,
            status=status,
            server=headers.get("server", ""),
            upgrade=headers.get("upgrade", ""),
        )
        if status == 101:
            frame_type, frame_text = read_frame(sock)
            result.frame_type = frame_type
            result.frame_payload = frame_text
            result.frame_excerpt = frame_text[:160]
        return result


def ensure_connection_frame(result: ProbeResult) -> bool:
    if result.status != 101 or result.frame_type != "text":
        return False
    try:
        payload = json.loads(result.frame_payload)
    except json.JSONDecodeError:
        return 'client_id' in result.frame_payload and '"id"' in result.frame_payload
    return (
        isinstance(payload, dict)
        and payload.get("type") == "server"
        and payload.get("action") == "connection"
        and "id" in payload
        and "client_id" in payload
    )


def print_summary(results: list[ProbeResult]) -> None:
    print("label\tstatus\tserver\tupgrade\tpath\tframe")
    for result in results:
        frame = result.frame_type or "-"
        if result.frame_excerpt:
            frame += ":" + result.frame_excerpt.replace("\n", " ")
        print(
            f"{result.label}\t{result.status}\t{result.server or '-'}\t{result.upgrade or '-'}\t{result.path}\t{frame}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("default", "allow-encoded-slashes"), default="default")
    parser.add_argument("--base-url", default="http://127.0.0.1/node/jupyter/8888")
    args = parser.parse_args()

    wait_for_http(args.base_url + "/api")

    root = websocket_probe(args.base_url, "/api/chat/ws/untitled.chat", "root")
    nested = websocket_probe(args.base_url, "/api/chat/ws/test%2Funtitled.chat", "nested")
    results = [root, nested]
    print_summary(results)

    problems = []
    if not ensure_connection_frame(root):
        problems.append("root chat did not upgrade cleanly and deliver a Jupyter Chat connection frame")

    if args.mode == "default":
        if nested.status != 404:
            problems.append(f"nested chat expected Apache 404 in default mode, got {nested.status}")
        if nested.upgrade:
            problems.append("nested chat unexpectedly upgraded in default mode")
        if nested.server and "apache" not in nested.server.lower():
            problems.append(f"nested chat expected Apache server header when present, got {nested.server}")
    else:
        if not ensure_connection_frame(nested):
            problems.append("nested chat did not reach Jupyter after enabling AllowEncodedSlashes NoDecode")

    if problems:
        for problem in problems:
            print(f"ERROR: {problem}", file=sys.stderr)
        return 1

    if args.mode == "default":
        print("Observed expected failing behavior: root WebSocket succeeds, nested encoded-slash path is rejected by Apache.")
    else:
        print("Observed workaround behavior: both root and nested WebSocket paths reach Jupyter.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
