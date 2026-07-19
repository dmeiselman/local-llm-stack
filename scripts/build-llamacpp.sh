#!/usr/bin/env bash
# Build llama.cpp with CUDA for your GPU. Idempotent-ish: re-running rebuilds.
# Verified recipe for 2x RTX 3060 (Ampere, arch 86) on Ubuntu 24.04 / CUDA 12.8.
#
# Prereqs (install once, needs sudo -- run yourself):
#   sudo apt update && sudo apt install -y git cmake build-essential
#   + a working NVIDIA driver and CUDA toolkit (nvidia-smi should list your GPUs)
# Do NOT `apt install nvidia-cuda-toolkit` if you already have a CUDA toolkit
# from NVIDIA's repo -- it installs a second, conflicting CUDA.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=lib.sh
source scripts/lib.sh

# nvcc may not be on PATH even when CUDA is installed; add the usual location.
export PATH="/usr/local/cuda/bin:$PATH"

if [[ ! -d "$LLAMACPP_DIR" ]]; then
  info "cloning llama.cpp into $LLAMACPP_DIR"
  git clone https://github.com/ggml-org/llama.cpp.git "$LLAMACPP_DIR"
fi

cd "$LLAMACPP_DIR"
info "building (CUDA arch $CUDA_ARCH, -j$BUILD_JOBS)"
# -j6 not -j\$(nproc): parallel nvcc is memory-hungry; 12 jobs can OOM a 16 GB box.
cmake --preset release -DGGML_CUDA=1 -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCH"
cmake --build --preset release -j"$BUILD_JOBS"

echo
echo "Built. Binary: $LLAMACPP_DIR/build/bin/llama-server"
echo "Quick check:  $LLAMACPP_DIR/build/bin/llama-server --version"
echo "NOTE: set LLAMACPP_BIN in scripts/lib.sh if your binary path differs."
