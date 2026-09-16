#!/bin/sh

set -o errexit

# needed to install first to build jupyter-chat from source
python -mpip install --no-cache-dir nodeenv
nodeenv --python-virtualenv

python -mpip install --no-cache-dir -r requirements.txt

# ACP adapters for Claude Code and Codex
# https://jupyter-ai.readthedocs.io/en/latest/getting-started.html#install-agents
npm install -g  @agentclientprotocol/claude-agent-acp @agentclientprotocol/codex-acp
