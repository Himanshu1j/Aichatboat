#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
MODEL="models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
mkdir -p models vendor
if [[ "${FORCE_REBUILD:-0}" == "1" && -d vendor/llama.cpp/build ]]; then
  echo "Removing llama.cpp build output for a clean build on this system..."
  rm -rf vendor/llama.cpp/build
fi
if [[ ! -s "$MODEL" ]]; then
  echo "Downloading official Qwen2.5 1.5B Instruct Q4_K_M GGUF..."
  curl -L --fail --retry 3 -o "$MODEL.part" 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf'
  mv "$MODEL.part" "$MODEL"
fi
if [[ ! -x vendor/llama.cpp/build/bin/llama-server ]]; then
  if [[ ! -d vendor/llama.cpp/.git ]]; then git clone --depth 1 https://github.com/ggml-org/llama.cpp vendor/llama.cpp; fi
  cmake -S vendor/llama.cpp -B vendor/llama.cpp/build -DGGML_NATIVE=ON -DGGML_OPENMP=ON -DCMAKE_BUILD_TYPE=Release
  cmake --build vendor/llama.cpp/build --config Release -j"$(nproc)" --target llama-server
fi
echo "Setup complete. Start with ./start.sh"
