#!/usr/bin/env bash

set -euo pipefail

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    echo "usage: $0 [MODEL] [LLAMA_SERVER_ARGS...]" >&2
    echo "" >&2
    echo "MODEL is an optional local GGUF file. Without it, the default Gemma 4 model is downloaded." >&2
    echo "" >&2
    echo "Environment:" >&2
    echo "  BUILD_DIR          CMake build directory (default: <repo>/build)" >&2
    echo "  BUILD_JOBS         Build parallelism (default: nproc)" >&2
    echo "  CUDA_ARCHITECTURES CUDA architecture passed to CMake (default: auto)" >&2
    echo "  GPU_LAYERS         Layers to offload (default: all)" >&2
    echo "  HF_REPO            Default Hugging Face model repository" >&2
    exit 1
fi

if [[ $# -gt 0 && $1 != -* ]]; then
    model=$1
    shift

    if [[ ! -f "$model" ]]; then
        echo "error: model file not found: $model" >&2
        exit 1
    fi

    model_args=(--model "$model")
else
    hf_repo=${HF_REPO:-google/gemma-4-12B-it-qat-q4_0-gguf}
    model_args=(--hf-repo "$hf_repo")
fi

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
build_dir=${BUILD_DIR:-"$repo_dir/build"}
build_jobs=${BUILD_JOBS:-$(nproc)}
gpu_layers=${GPU_LAYERS:-all}

cmake_args=(
    -S "$repo_dir"
    -B "$build_dir"
    -DCMAKE_BUILD_TYPE=Release
    -DGGML_CUDA=ON
    -DGGML_CCACHE=OFF
)

if [[ -n "${CUDA_ARCHITECTURES:-}" ]]; then
    cmake_args+=("-DCMAKE_CUDA_ARCHITECTURES=$CUDA_ARCHITECTURES")
fi

cmake "${cmake_args[@]}"
cmake --build "$build_dir" --parallel "$build_jobs" --target llama-server

exec "$build_dir/bin/llama-server" "${model_args[@]}" --gpu-layers "$gpu_layers" "$@"
