#!/bin/sh

set -o errexit

# need to install nodeenv first to build jupyterlab-chat
python -mpip install --no-cache-dir --no-deps -c requirements.txt nodeenv
nodeenv --python-virtualenv

python -mpip install --no-cache-dir --no-deps -r requirements.txt

# ACP adapters for Claude Code and Codex
# https://jupyter-ai.readthedocs.io/en/latest/getting-started.html#install-agents
npm install -g  @agentclientprotocol/claude-agent-acp @agentclientprotocol/codex-acp
