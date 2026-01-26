#!/usr/bin/env bash
# 使用 FlashInfer 后端启动 SGLang 服务，可配置 page_size
# 用法: ./start_server.sh [page_size] [model_path]
# 示例: ./start_server.sh 16
#       ./start_server.sh 64 meta-llama/Llama-3.1-8B-Instruct

set -e

PAGE_SIZE="${1:-16}"
MODEL_PATH="${2:-meta-llama/Llama-3.1-8B-Instruct}"
PORT="${SGLANG_PORT:-30000}"

echo "Starting SGLang with:"
echo "  --attention-backend flashinfer"
echo "  --page-size ${PAGE_SIZE}"
echo "  --model-path ${MODEL_PATH}"
echo "  --port ${PORT}"
echo ""

python3 -m sglang.launch_server \
  --model-path "${MODEL_PATH}" \
  --attention-backend flashinfer \
  --page-size "${PAGE_SIZE}" \
  --port "${PORT}" \
  "${@:3}"
