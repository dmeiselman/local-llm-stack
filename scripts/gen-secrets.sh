#!/usr/bin/env bash
# Generate fresh secrets and write them into the (gitignored) real config files.
#   - LiteLLM master key  -> config/litellm/.env
#   - SearXNG secret_key  -> printed, so you can drop it into settings.yml
# Run once at setup. Safe to re-run (it regenerates and overwrites).
set -euo pipefail
cd "$(dirname "$0")/.."

MASTER_KEY="sk-llm-$(openssl rand -hex 24)"
SEARXNG_SECRET="$(openssl rand -hex 32)"

# Write the LiteLLM .env (gitignored).
mkdir -p config/litellm
printf 'LITELLM_MASTER_KEY=%s\n' "$MASTER_KEY" > config/litellm/.env
chmod 600 config/litellm/.env

echo "Wrote config/litellm/.env with a fresh LITELLM_MASTER_KEY."
echo
echo "Use these values when you render the templates (render-configs.sh reads them):"
echo "  LITELLM_MASTER_KEY=$MASTER_KEY"
echo "  SEARXNG_SECRET=$SEARXNG_SECRET"
echo
echo "Add this to your shell rc so clients (opencode, etc.) can see the key:"
echo "  export LITELLM_MASTER_KEY=$MASTER_KEY"
