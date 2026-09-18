#!/bin/sh

set -o errexit

python -mpip install --no-cache-dir -r requirements.txt
nodeenv --python-virtualenv

# ACP adapters for Claude Code and Codex
# https://jupyter-ai.readthedocs.io/en/latest/getting-started.html#install-agents
npm install -g  @agentclientprotocol/claude-agent-acp @agentclientprotocol/codex-acp
