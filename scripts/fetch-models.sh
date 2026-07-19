#!/usr/bin/env bash
# Download the three reference GGUF models into MODELS_DIR using huggingface-cli.
# These are LARGE (13-19 GB each). You can comment out any you do not want.
#
# Prereq:  pip install -U "huggingface_hub[cli]"
#
# The exact repos/filenames below match what the reference llama-swap config
# expects. If you pick different quants, update config/llama-swap/config.yaml too.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=lib.sh
source scripts/lib.sh

command -v huggingface-cli >/dev/null || die 'huggingface-cli not found: pip install -U "huggingface_hub[cli]"'
mkdir -p "$MODELS_DIR"

get() {  # repo  filename
  info "downloading $2"
  huggingface-cli download "$1" "$2" --local-dir "$MODELS_DIR"
}

# --- Daily driver: Qwen3.6-35B-A3B MoE, Q3_K_XL (~18 GB) ---------------------
get bartowski/Qwen_Qwen3.6-35B-A3B-GGUF Qwen_Qwen3.6-35B-A3B-Q3_K_XL.gguf

# --- Coder: Qwen3.6-27B dense, UD-Q4_K_XL (~16 GB) ---------------------------
# NOTE: repo/filename vary by publisher; adjust if unsloth's path differs.
get unsloth/Qwen3.6-27B-GGUF Qwen_Qwen3.6-27B-UD-Q4_K_XL.gguf || \
  info "27B download failed -- check the current unsloth repo path and edit this script"

# --- Long-context: Gemma-4-26B-A4B QAT, text-only Q4_0 (~13 GB) --------------
# The stock GGUF may include a vision/audio projector that some runtimes reject;
# a text-only export is what the reference config uses. See recipes/04 notes.
get ggml-org/gemma-4-26b-a4b-it-qat-GGUF gemma4-26b-qat-text-Q4_0.gguf || \
  info "gemma4 download failed -- confirm the current QAT GGUF repo/filename and edit this script"

echo
echo "Models in $MODELS_DIR:"
ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null || true
echo "If a filename here differs from config/llama-swap/config.yaml, make them match."
