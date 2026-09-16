FROM python:3.12-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends apache2 apache2-bin ca-certificates curl procps \
    && rm -rf /var/lib/apt/lists/*

RUN a2dismod mpm_event >/dev/null 2>&1 || true \
    && a2enmod mpm_prefork proxy proxy_http proxy_wstunnel rewrite headers >/dev/null

RUN pip install \
      jupyterlab==4.6.3 \
      jupyter-server==2.21.1 \
      jupyter-ai==3.2.0 \
      jupyterlab-chat==0.25.0 \
    && python - <<'PY'
import importlib.metadata as md
import importlib.util
expected = {
    'jupyter-ai': '3.2.0',
    'jupyterlab-chat': '0.25.0',
    'jupyterlab': '4.6.3',
    'jupyter_server': '2.21.1',
}
for name, version in expected.items():
    actual = md.version(name)
    if actual != version:
        raise SystemExit(f'{name} expected {version}, got {actual}')
for forbidden in ('jupyter_collaboration', 'ypy_websocket'):
    if importlib.util.find_spec(forbidden) is not None:
        raise SystemExit(f'Unexpected RTC package installed: {forbidden}')
print('Pinned versions and RTC-free package set verified.')
PY

WORKDIR /opt/reproducer
RUN mkdir -p /work /var/run/apache2 /var/lock/apache2

COPY jupyter/ jupyter/
COPY entrypoint.sh run.sh probe.sh teardown.sh validate.sh probe.py issue-jupyterlab-chat.md README.md ./

EXPOSE 80
ENTRYPOINT ["/opt/reproducer/entrypoint.sh"]
