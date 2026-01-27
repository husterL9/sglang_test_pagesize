#!/usr/bin/env bash
# 优化版 benchmark，用于突出 page_size 的影响
# 用法: ./run_benchmark_optimized.sh [page_size] [output_prefix]
# 示例: ./run_benchmark_optimized.sh 16
#       ./run_benchmark_optimized.sh 64 optimized_test

set -e

PAGE_SIZE="${1:-16}"
OUTPUT_PREFIX="${2:-optimized_pagesize}"
HOST="${SGLANG_HOST:-127.0.0.1}"
PORT="${SGLANG_PORT:-30000}"
MODEL="${SGLANG_BENCH_MODEL:-Qwen/Qwen2.5-7B-Instruct}"

# HuggingFace 镜像源配置
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 优化参数：突出 page_size 影响
# 1. 输入长度设为 page_size 的倍数（例如：page_size * 32）
#    这样不同 page_size 下都能充分利用整页
INPUT_LEN=$((PAGE_SIZE * 32))
if [ $INPUT_LEN -lt 256 ]; then
    INPUT_LEN=256  # 最小 256 tokens
elif [ $INPUT_LEN -gt 2048 ]; then
    INPUT_LEN=2048  # 最大 2048 tokens
fi

# 2. 降低并发，避免请求堆积
MAX_CONCURRENCY="${MAX_CONCURRENCY:-16}"

# 3. 降低请求速率，让服务器能跟上
REQUEST_RATE="${REQUEST_RATE:-3}"

# 4. 增加请求数量，让 prefix cache 有更多命中机会
NUM_PROMPTS="${NUM_PROMPTS:-1000}"

# 5. 较短的输出，减少生成时间，突出 prefix cache 的影响
OUTPUT_LEN="${RANDOM_OUTPUT_LEN:-128}"

# 6. 使用 random 数据集（如果可用 sharegpt 会更好）
DATASET="${DATASET:-random}"

OUTPUT_FILE="${OUTPUT_PREFIX}_page${PAGE_SIZE}_$(date +%Y%m%d_%H%M%S).jsonl"

echo "=========================================="
echo "优化版 Benchmark - 突出 Page Size 影响"
echo "=========================================="
echo "Page Size: ${PAGE_SIZE}"
echo "输入长度: ${INPUT_LEN} tokens (${PAGE_SIZE} * 32)"
echo "输出长度: ${OUTPUT_LEN} tokens"
echo "请求数量: ${NUM_PROMPTS}"
echo "请求速率: ${REQUEST_RATE} req/s"
echo "最大并发: ${MAX_CONCURRENCY}"
echo "数据集: ${DATASET}"
echo "输出文件: ${OUTPUT_FILE}"
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
  --random-input-len "${INPUT_LEN}" \
  --random-output-len "${OUTPUT_LEN}" \
  --random-range-ratio 0.2 \
  --output-file "${OUTPUT_FILE}" \
  --output-details \
  --flush-cache

echo ""
echo "=========================================="
echo "结果已保存到: ${OUTPUT_FILE}"
echo "=========================================="
