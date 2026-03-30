#!/usr/bin/env bash
# 自动化 sweep：对多种 page_size 分别启动服务、跑 bench、记录结果
# 用法: ./sweep_page_sizes.sh [model_path]
# 环境变量: PAGE_SIZES（空格分隔，默认 "1 16 32 64 128"）

set -e

MODEL_PATH="${1:-Qwen/Qwen2.5-7B-Instruct}"
PAGE_SIZES="${PAGE_SIZES:-1 16 32 64 128 256}"
HOST="${SGLANG_HOST:-127.0.0.1}"
PORT="${SGLANG_PORT:-30000}"
RESULTS_DIR="${RESULTS_DIR:-./results}"
WAIT_READY_SEC="${WAIT_READY_SEC:-120}"

# HuggingFace 镜像源配置
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 基准参数：默认固定 workload，便于公平对比不同服务端 page_size
MAX_CONCURRENCY="${MAX_CONCURRENCY:-16}"
REQUEST_RATE="${REQUEST_RATE:-3}"
NUM_PROMPTS="${NUM_PROMPTS:-1000}"
INPUT_LEN="${RANDOM_INPUT_LEN:-1024}"
OUTPUT_LEN="${RANDOM_OUTPUT_LEN:-128}"
RANDOM_RANGE_RATIO="${RANDOM_RANGE_RATIO:-1}"
DATASET="${DATASET:-random}"
DATASET_PATH="${DATASET_PATH:-}"
BENCHMARK_SEED="${BENCHMARK_SEED:-20260331}"

mkdir -p "${RESULTS_DIR}"

if [ "${DATASET}" = "random" ]; then
  echo "提示: 当前会用固定种子 BENCHMARK_SEED=${BENCHMARK_SEED} 复用同一批随机 prompts。"
  echo "如需跨机器/跨时间进一步固定数据源，可额外设置 DATASET_PATH=/path/to/local/sharegpt.json。"
  echo ""
fi

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

  echo "输入长度: ${INPUT_LEN} tokens (固定)"
  echo "输出长度: ${OUTPUT_LEN} tokens (固定)"
  echo "数据集: ${DATASET}, random_range_ratio=${RANDOM_RANGE_RATIO}"
  if [ -n "${DATASET_PATH}" ]; then
    echo "数据源文件: ${DATASET_PATH}"
  fi
  echo "Benchmark seed: ${BENCHMARK_SEED}"
  echo "使用优化参数: 并发=${MAX_CONCURRENCY}, 速率=${REQUEST_RATE} req/s"
  echo ""

  # 启动服务（后台）
  # 注意：CUDA_VISIBLE_DEVICES 需要通过环境变量设置，不是命令行参数
  export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
  python3 -m sglang.launch_server \
    --model-path "${MODEL_PATH}" \
    --attention-backend flashinfer \
    --page-size "${PS}" \
    --port "${PORT}" \
    > "${RESULTS_DIR}/server_page${PS}.log" 2>&1 &
  SVR_PID=$!

  if ! wait_for_server; then
    kill -9 $SVR_PID 2>/dev/null || true
    echo "跳过 page_size=${PS}（服务器启动失败）"
    echo ""
    continue
  fi

  # 跑 bench，结果文件名带 page_size（保持同一 workload）
  OUT_FILE="${RESULTS_DIR}/bench_page${PS}_$(date +%Y%m%d_%H%M%S).jsonl"
  BENCH_ARGS=(
    --backend sglang
    --host "${HOST}"
    --port "${PORT}"
    --model "${MODEL_PATH}"
    --dataset-name "${DATASET}"
    --num-prompts "${NUM_PROMPTS}"
    --request-rate "${REQUEST_RATE}"
    --max-concurrency "${MAX_CONCURRENCY}"
    --random-input-len "${INPUT_LEN}"
    --random-output-len "${OUTPUT_LEN}"
    --random-range-ratio "${RANDOM_RANGE_RATIO}"
    --output-file "${OUT_FILE}"
    --output-details
    --flush-cache
  )
  if [ -n "${DATASET_PATH}" ]; then
    BENCH_ARGS+=(--dataset-path "${DATASET_PATH}")
  fi
  BENCHMARK_SEED="${BENCHMARK_SEED}" python3 run_seeded_bench.py "${BENCH_ARGS[@]}" || true

  # 停服务
  kill -15 $SVR_PID 2>/dev/null || true
  for _ in $(seq 1 30); do kill -0 $SVR_PID 2>/dev/null || break; sleep 1; done
  kill -9 $SVR_PID 2>/dev/null || true
  sleep 3

  echo "Done page_size=${PS} -> ${OUT_FILE}"
  echo ""
done

echo "Sweep finished. Results in ${RESULTS_DIR}/"
