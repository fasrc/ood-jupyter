# Jupyter Chat encoded-slash reproducer

This reproducer demonstrates a proxy-layer failure for nested Jupyter Chat documents when `jupyter-ai==3.2.0` uses `jupyterlab-chat==0.25.0` in RTC-free WebSocket mode behind Apache.

It is fully isolated from the Open OnDemand app in this repository and does **not** alter production behavior.

## What it reproduces

`jupyterlab-chat` builds the per-chat WebSocket path as:

```text
/api/chat/ws/${encodeURIComponent(chatPath)}
```

That works for a root chat:

- `untitled.chat` -> `/api/chat/ws/untitled.chat`

But a nested chat path encodes `/` into `%2F`:

- `test/untitled.chat` -> `/api/chat/ws/test%2Funtitled.chat`

With Apache's default encoded-slash handling, the nested request is rejected with an Apache-generated `404` before it reaches Tornado/Jupyter.

This is distinct from `jupyter-ai-acp-client` issue #109, which involves ACP HTTP endpoints rather than the non-RTC chat WebSocket transport.

## Pinned versions

- `jupyter-ai==3.2.0`
- `jupyterlab-chat==0.25.0`
- `jupyterlab==4.6.3`
- `jupyter-server==2.21.1`
- Apache HTTP Server 2.4.x in front of Jupyter
- RTC packages intentionally absent: `jupyter-collaboration`, `ypy-websocket`

## Files

- `Dockerfile` - single-container Apache + Jupyter reproducer
- `requirements.lock` - fully pinned Python dependency set for deterministic rebuilds
- `run.sh` - build and start the reproducer
- `probe.sh` - run the automated Apache/Jupyter regression probe
- `teardown.sh` - stop and remove the container
- `validate.sh` - basic syntax/build validation
- `issue-jupyterlab-chat.md` - upstream issue draft ready to paste

## Quick start

From this directory:

```bash
./run.sh
./probe.sh
```

`run.sh` publishes Apache on `127.0.0.1:8080` by default so the intentionally local-only, unauthenticated Jupyter server is not exposed beyond the host.

## Dev Container / Codespaces

This repository now includes a repo-level Dev Container at `/home/runner/work/ood-jupyter/ood-jupyter/.devcontainer/devcontainer.json`.

- It builds directly from `/home/runner/work/ood-jupyter/ood-jupyter/reproducers/jupyter-chat-encoded-slash/Dockerfile`.
- It runs the reproducer container automatically on start by using the Dockerfile's existing entrypoint.
- In a GitHub Codespace, forward port `80` and open:

```text
/node/jupyter/8888/lab
```

If you change the reproducer Dockerfile or locked dependencies, rebuild the Dev Container so the Codespace uses the updated image.

Then open:

```text
http://localhost:8080/node/jupyter/8888/lab
```

To stop and remove the container:

```bash
./teardown.sh
```

## Automated probe expectations

The probe connects through Apache, not directly to Jupyter.

| Mode | WebSocket path | Expected result | Evidence |
| --- | --- | --- | --- |
| default | `/node/jupyter/8888/api/chat/ws/untitled.chat` | `101` upgrade | receives the initial Jupyter Chat connection frame |
| default | `/node/jupyter/8888/api/chat/ws/test%2Funtitled.chat` | `404` | Apache-generated response, no upgrade |
| workaround | `/node/jupyter/8888/api/chat/ws/test%2Funtitled.chat` | `101` upgrade | reaches Jupyter once only `AllowEncodedSlashes NoDecode` changes |

The probe exits nonzero if the expected mode-specific behavior is not observed.

## Manual UI reproduction

1. Start the reproducer:

   ```bash
   ./run.sh
   ```

2. Open JupyterLab through Apache:

   ```text
   http://localhost:8080/node/jupyter/8888/lab
   ```

3. Optional but helpful: open browser DevTools and watch the **Network** tab for WebSocket requests.

4. In the left side panel, use the Jupyter AI chat button to create a root-level chat.
   - Expected transport: `/node/jupyter/8888/api/chat/ws/untitled.chat`
   - Expected result: the WebSocket upgrades successfully and the chat initializes normally.
   - If your local AI setup has no model credentials configured, use the successful WebSocket/network evidence as the primary signal.

5. Create a directory named `test` in the file browser.

6. Navigate into `test`, then choose **File > New > Chat**.
   - Expected transport: `/node/jupyter/8888/api/chat/ws/test%2Funtitled.chat`
   - Expected result in default mode: Apache returns `404 Not Found` before the request reaches Jupyter.
   - Expected UI symptom: the nested chat does not fully initialize; the persona selector can remain loading, flash, or disappear.

## Workaround / fixed-mode demonstration

The default mode intentionally reproduces the failure.

To demonstrate that only Apache's encoded-slash policy changes the outcome:

```bash
./teardown.sh
./run.sh --allow-encoded-slashes
./probe.sh --allow-encoded-slashes
```

That starts the same container image with Apache configured as:

```apache
AllowEncodedSlashes NoDecode
```

This is a deployment workaround, **not** the proposed upstream application fix.

## Proposed upstream application fix

At the application level, encode individual path components while preserving `/` separators, instead of applying `encodeURIComponent` to the whole logical path.

That is described in `issue-jupyterlab-chat.md` along with regression-test suggestions for nested paths and spaces.

## Validation

Basic syntax validation:

```bash
./validate.sh
```

Syntax validation plus a local Docker build:

```bash
./validate.sh --build
```

## Teardown

```bash
./teardown.sh
```

If you also want to remove the local image afterward:

```bash
docker rmi ood-jupyter-chat-encoded-slash-reproducer
```
