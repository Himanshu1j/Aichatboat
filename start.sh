#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
BIN="vendor/llama.cpp/build/bin/llama-server"
MODEL="models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
if [[ ! -x "$BIN" ]]; then echo "llama-server missing. Run ./setup.sh first." >&2; exit 1; fi
if [[ ! -s "$MODEL" ]]; then echo "Model missing. Run ./setup.sh first." >&2; exit 1; fi
"$BIN" -m "$MODEL" --host 127.0.0.1 --port 8081 -c 4096 -ngl 0 &
LLAMA_PID=$!
cleanup(){ kill "$LLAMA_PID" 2>/dev/null || true; wait "$LLAMA_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
python3 server.py
