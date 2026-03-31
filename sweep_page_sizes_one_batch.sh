#!/usr/bin/env bash
# 自动化 sweep：对多种 page_size 直接运行 sglang.bench_one_batch
# 用法: ./sweep_page_sizes_one_batch.sh [model_path] [extra bench_one_batch args...]
# 示例:
#   ./sweep_page_sizes_one_batch.sh Qwen/Qwen2.5-7B-Instruct
#   BATCH_SIZE=32 RANDOM_INPUT_LEN=1024 RANDOM_OUTPUT_LEN=128 ./sweep_page_sizes_one_batch.sh
#   ./sweep_page_sizes_one_batch.sh Qwen/Qwen2.5-7B-Instruct --profile --profile-stage prefill

set -e

MODEL_PATH="${1:-Qwen/Qwen2.5-7B-Instruct}"
if [ "$#" -gt 0 ]; then
  shift
fi
EXTRA_ARGS=("$@")

PAGE_SIZES="${PAGE_SIZES:-1 16 32 64 128 256}"
RESULTS_DIR="${RESULTS_DIR:-./results}"
ATTENTION_BACKEND="${ATTENTION_BACKEND:-flashinfer}"

export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

BATCH_SIZE="${BATCH_SIZE:-32}"
INPUT_LEN="${RANDOM_INPUT_LEN:-1024}"
OUTPUT_LEN="${RANDOM_OUTPUT_LEN:-128}"
BENCHMARK_SEED="${BENCHMARK_SEED:-20260331}"
LOG_DECODE_STEP="${LOG_DECODE_STEP:-0}"
RUN_NAME_PREFIX="${RUN_NAME_PREFIX:-page_size_one_batch}"

mkdir -p "${RESULTS_DIR}"

echo "提示: 当前使用 bench_one_batch 做 page_size sweep。"
echo "它会绕过 server、scheduler 和 prefix cache，更适合隔离观察 page_size 对 prefill / decode kernel 的影响。"
echo "模型: ${MODEL_PATH}"
echo "后端: ${ATTENTION_BACKEND}"
echo "batch_size: ${BATCH_SIZE}, input_len: ${INPUT_LEN}, output_len: ${OUTPUT_LEN}"
echo "page_sizes: ${PAGE_SIZES}"
echo "benchmark_seed: ${BENCHMARK_SEED}"
echo ""

for PS in ${PAGE_SIZES}; do
  echo "=============================================="
  echo "Page size: ${PS}"
  echo "=============================================="

  TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
  OUT_FILE="${RESULTS_DIR}/one_batch_page${PS}_${TIMESTAMP}.jsonl"
  LOG_FILE="${RESULTS_DIR}/one_batch_page${PS}_${TIMESTAMP}.log"
  RUN_NAME="${RUN_NAME_PREFIX}_page${PS}"

  BENCH_ARGS=(
    --model-path "${MODEL_PATH}"
    --attention-backend "${ATTENTION_BACKEND}"
    --page-size "${PS}"
    --batch-size "${BATCH_SIZE}"
    --input-len "${INPUT_LEN}"
    --output-len "${OUTPUT_LEN}"
    --run-name "${RUN_NAME}"
    --result-filename "${OUT_FILE}"
  )

  if [ "${LOG_DECODE_STEP}" -gt 0 ]; then
    BENCH_ARGS+=(--log-decode-step "${LOG_DECODE_STEP}")
  fi

  if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
    BENCH_ARGS+=("${EXTRA_ARGS[@]}")
  fi

  if BENCHMARK_SEED="${BENCHMARK_SEED}" python3 run_seeded_one_batch.py "${BENCH_ARGS[@]}" > "${LOG_FILE}" 2>&1; then
    echo "Done page_size=${PS} -> ${OUT_FILE}"
    echo "Log written to: ${LOG_FILE}"
  else
    echo "bench_one_batch failed for page_size=${PS}"
    echo "Log written to: ${LOG_FILE}"
  fi
  echo ""
done

echo "Sweep finished. Results in ${RESULTS_DIR}/"
