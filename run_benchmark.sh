#!/usr/bin/env bash
# 对已运行的 SGLang 服务执行 bench_serving
# 用法: ./run_benchmark.sh [output_prefix]
# 需要先单独启动服务（或由 sweep 脚本启动）

set -e

OUTPUT_PREFIX="${1:-sglang_pagesize}"
HOST="${SGLANG_HOST:-127.0.0.1}"
PORT="${SGLANG_PORT:-30000}"
MODEL="${SGLANG_BENCH_MODEL:-meta-llama/Llama-3.1-8B-Instruct}"

# 可调参数
NUM_PROMPTS="${NUM_PROMPTS:-500}"
REQUEST_RATE="${REQUEST_RATE:-50}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-128}"
DATASET="${DATASET:-random}"
RANDOM_INPUT_LEN="${RANDOM_INPUT_LEN:-512}"
RANDOM_OUTPUT_LEN="${RANDOM_OUTPUT_LEN:-256}"

OUTPUT_FILE="${OUTPUT_PREFIX}_$(date +%Y%m%d_%H%M%S).jsonl"

echo "Running bench_serving -> ${OUTPUT_FILE}"
echo "  backend=sglang, host=${HOST}, port=${PORT}"
echo "  num_prompts=${NUM_PROMPTS}, request_rate=${REQUEST_RATE}, max_concurrency=${MAX_CONCURRENCY}"
echo "  dataset=${DATASET}, input_len=${RANDOM_INPUT_LEN}, output_len=${RANDOM_OUTPUT_LEN}"
echo ""

python3 -m sglang.bench_serving \
  --backend sglang \
  --host "${HOST}" \
  --port "${PORT}" \
  --model "${MODEL}" \
  --dataset-name "${DATASET}" \
  --num-prompts "${NUM_PROMPTS}" \
  --request-rate "${REQUEST_RATE}" \
  --max-concurrency "${MAX_CONCURRENCY}" \
  --random-input-len "${RANDOM_INPUT_LEN}" \
  --random-output-len "${RANDOM_OUTPUT_LEN}" \
  --random-range-ratio 0.5 \
  --output-file "${OUTPUT_FILE}" \
  --output-details \
  --flush-cache

echo ""
echo "Results written to: ${OUTPUT_FILE}"
