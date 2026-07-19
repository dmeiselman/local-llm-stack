#!/usr/bin/env bash
# Shared config for the helper scripts. Edit these to match YOUR machine, or
# override any of them via the environment before running a script:
#   MODELS_DIR=/data/models ./scripts/fetch-models.sh
#
# This file is sourced by the other scripts; it is not meant to be run directly.

# Where your llama.cpp checkout lives (the build/ dir is created under it).
: "${LLAMACPP_DIR:=$HOME/llama.cpp}"
# The llama-server binary produced by the build.
: "${LLAMACPP_BIN:=$LLAMACPP_DIR/build/bin/llama-server}"
# Where GGUF model files are stored.
: "${MODELS_DIR:=$HOME/models}"
# Where the llama-swap binary + its config.yaml live.
: "${LLAMASWAP_DIR:=$HOME/llama-swap}"
# Where the docker compose stack (LiteLLM + SearXNG) is deployed.
: "${STACK_DIR:=$HOME/llm-stack}"
# GPU CUDA architecture: 86 = Ampere (RTX 30-series). 89 = Ada (40-series),
# 75 = Turing (20-series). Match your card.
: "${CUDA_ARCH:=86}"
# Build parallelism. Keep modest on low-RAM boxes (nvcc is memory hungry).
: "${BUILD_JOBS:=6}"

# Repo root (directory that contains this scripts/ folder).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">> $*"; }
