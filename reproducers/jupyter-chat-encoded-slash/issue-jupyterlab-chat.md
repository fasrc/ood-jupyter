# Draft upstream issue for `jupyterlab/jupyter-chat`

## Title
Nested chat WebSocket path uses whole-path `encodeURIComponent`, causing Apache 404 on `%2F` before Tornado sees `/api/chat/ws/...`

## Versions
- `jupyter-ai==3.2.0`
- `jupyterlab-chat==0.25.0`
- `jupyterlab==4.6.3`
- `jupyter-server==2.21.1`
- Apache HTTP Server 2.4.x reverse proxy
- RTC packages intentionally absent (`jupyter-collaboration`, `ypy-websocket` not installed), so chat uses the non-RTC `/api/chat/ws/<chat-path>` transport

## Reproducer
A self-contained reproducer is attached in this repository under `reproducers/jupyter-chat-encoded-slash/`.

Commands:

```bash
cd reproducers/jupyter-chat-encoded-slash
./run.sh
./probe.sh
```

Optional workaround-only mode:

```bash
./teardown.sh
./run.sh --allow-encoded-slashes
./probe.sh --allow-encoded-slashes
```

## Actual behavior
With Apache's default encoded-slash handling, a root chat works:

- `/api/chat/ws/untitled.chat` -> HTTP `101`, connection reaches Jupyter/Tornado, initial Jupyter Chat connection frame is received

But a nested chat fails before it reaches Jupyter:

- `/api/chat/ws/test%2Funtitled.chat` -> Apache-generated HTTP `404`, no WebSocket upgrade

In Jupyter AI this leaves the nested chat without a server chat id/persona-manager session; the persona selector can remain loading, flash briefly, or disappear.

## Expected behavior
Nested chat paths should work the same as root paths when the logical chat path is `test/untitled.chat`.

## Root-cause evidence
The frontend currently builds the non-RTC per-chat WebSocket URL by applying `encodeURIComponent` to the entire chat path:

```ts
/api/chat/ws/${encodeURIComponent(chatPath)}
```

For a nested chat, `test/untitled.chat` becomes `test%2Funtitled.chat`.

`jupyterlab-chat`'s server-side route is designed to accept a single captured path segment and rely on Tornado to decode it back to the slash-containing logical path after routing. That works only if the request reaches Tornado.

Under Apache's default `AllowEncodedSlashes Off`, the `%2F` request is rejected at the proxy layer with an Apache 404 before it is forwarded upstream.

This appears to align with the whole-path encoding introduced around PR #530: the transport wants a slash-preserving path representation, but whole-path `encodeURIComponent` turns path separators into encoded slashes that some proxies reject.

## Distinguishing evidence: Apache vs Tornado
The reproducer shows a clear proxy/backend split:

| Path | Result | Server evidence |
| --- | --- | --- |
| `/api/chat/ws/untitled.chat` | `101` upgrade | reaches Jupyter/Tornado and receives the initial connection frame |
| `/api/chat/ws/test%2Funtitled.chat` | `404` | Apache-generated response, no upgrade |

## Proposed application-level fix
Encode each path component while preserving `/` separators instead of encoding the whole path as one segment.

Conceptually:

```ts
chatPath
  .split('/')
  .map(encodeURIComponent)
  .join('/')
```

That keeps nested paths routable through common reverse proxies while still encoding spaces and other reserved characters within each component.

## Regression-test suggestion
Add a frontend regression test covering at least:

- `untitled.chat` -> unchanged root path
- `test/untitled.chat` -> slash preserved
- `dir with spaces/untitled chat.chat` -> spaces encoded inside each component, slash preserved

## Additional note
The browser may surface a close-code-`1006`/fallback-style symptom after the failed handshake. That can obscure the real cause, because the real failure is the proxy-layer rejection of the `%2F` request before the WebSocket handler is reached.
