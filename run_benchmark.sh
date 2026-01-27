#!/usr/bin/env bash
# 对已运行的 SGLang 服务执行 bench_serving
# 用法: ./run_benchmark.sh [output_prefix]
# 需要先单独启动服务（或由 sweep 脚本启动）

set -e

OUTPUT_PREFIX="${1:-sglang_pagesize}"
HOST="${SGLANG_HOST:-127.0.0.1}"
PORT="${SGLANG_PORT:-30000}"
MODEL="${SGLANG_BENCH_MODEL:-Qwen/Qwen2.5-7B-Instruct}"

# HuggingFace 镜像源配置（与 start_server.sh 保持一致）
# 确保 benchmark 工具加载 tokenizer 时也使用镜像源
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 可调参数
# NUM_PROMPTS="${NUM_PROMPTS:-500}"
# REQUEST_RATE="${REQUEST_RATE:-50}"
# MAX_CONCURRENCY="${MAX_CONCURRENCY:-128}"
# DATASET="${DATASET:-random}"
# RANDOM_INPUT_LEN="${RANDOM_INPUT_LEN:-512}"
# RANDOM_OUTPUT_LEN="${RANDOM_OUTPUT_LEN:-256}"

# 优化建议（突出 page_size 影响）：
# 1. 降低并发，避免请求堆积（建议 8-16）
# 2. 降低请求速率，让服务器能跟上（建议 2-5 req/s）
# 3. 增加请求数量，让 prefix cache 有更多命中机会
# 4. 调整输入长度为 page_size 的倍数，突出差异
#    例如：page_size=16 时用 512 (32页), page_size=64 时用 512 (8页)
# 5. 使用 sharegpt 数据集（有重复前缀）或增加重复请求

NUM_PROMPTS="${NUM_PROMPTS:-1000}"
REQUEST_RATE="${REQUEST_RATE:-3}"
MAX_CONCURRENCY="${MAX_CONCURRENCY:-16}"
DATASET="${DATASET:-random}"
RANDOM_INPUT_LEN="${RANDOM_INPUT_LEN:-512}"
RANDOM_OUTPUT_LEN="${RANDOM_OUTPUT_LEN:-128}"

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
