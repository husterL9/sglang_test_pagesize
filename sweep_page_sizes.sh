#!/usr/bin/env bash
# 自动化 sweep：对多种 page_size 分别启动服务、跑 bench、记录结果
# 用法: ./sweep_page_sizes.sh [model_path]
# 环境变量: PAGE_SIZES（空格分隔，默认 "1 16 32 64 128"）

set -e

MODEL_PATH="${1:-meta-llama/Llama-3.1-8B-Instruct}"
PAGE_SIZES="${PAGE_SIZES:-1 16 32 64 128}"
HOST="${SGLANG_HOST:-127.0.0.1}"
PORT="${SGLANG_PORT:-30000}"
RESULTS_DIR="${RESULTS_DIR:-./results}"
WAIT_READY_SEC="${WAIT_READY_SEC:-120}"

mkdir -p "${RESULTS_DIR}"

# 等待服务就绪
wait_for_server() {
  local max_tries=$((WAIT_READY_SEC / 5))
  local tries=0
  while [ "$tries" -lt "$max_tries" ]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://${HOST}:${PORT}/get_server_info" 2>/dev/null | grep -q "200"; then
      echo "Server ready."
      return 0
    fi
    tries=$((tries + 1))
    echo "Waiting for server... (${tries}/${max_tries})"
    sleep 5
  done
  echo "Server did not become ready in ${WAIT_READY_SEC}s"
  return 1
}

for PS in ${PAGE_SIZES}; do
  echo "=============================================="
  echo "Page size: ${PS}"
  echo "=============================================="

  # 启动服务（后台）
  python3 -m sglang.launch_server \
    --model-path "${MODEL_PATH}" \
    --attention-backend flashinfer \
    --page-size "${PS}" \
    --port "${PORT}" &
  SVR_PID=$!

  if ! wait_for_server; then
    kill -9 $SVR_PID 2>/dev/null || true
    echo "Skipping page_size=${PS}"
    continue
  fi

  # 跑 bench，结果文件名带 page_size
  OUT_FILE="${RESULTS_DIR}/bench_page${PS}_$(date +%Y%m%d_%H%M%S).jsonl"
  python3 -m sglang.bench_serving \
    --backend sglang \
    --host "${HOST}" \
    --port "${PORT}" \
    --model "${MODEL_PATH}" \
    --dataset-name random \
    --num-prompts 500 \
    --request-rate 50 \
    --max-concurrency 128 \
    --random-input-len 512 \
    --random-output-len 256 \
    --random-range-ratio 0.5 \
    --output-file "${OUT_FILE}" \
    --output-details \
    --flush-cache || true

  # 停服务
  kill -15 $SVR_PID 2>/dev/null || true
  for _ in $(seq 1 30); do kill -0 $SVR_PID 2>/dev/null || break; sleep 1; done
  kill -9 $SVR_PID 2>/dev/null || true
  sleep 3

  echo "Done page_size=${PS} -> ${OUT_FILE}"
  echo ""
done

echo "Sweep finished. Results in ${RESULTS_DIR}/"
