#!/usr/bin/env bash
# 批量测试多个 page_size，使用优化参数
# 用法: ./test_all_page_sizes.sh
# 会自动测试: 1, 16, 32, 64, 128, 256

set -e

# 要测试的 page_size 列表
PAGE_SIZES="1 16 32 64 128 256"
MODEL="${SGLANG_BENCH_MODEL:-Qwen/Qwen2.5-7B-Instruct}"
HOST="${SGLANG_HOST:-127.0.0.1}"
PORT="${SGLANG_PORT:-30000}"
RESULTS_DIR="${RESULTS_DIR:-./results}"

# HuggingFace 镜像源配置
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

mkdir -p "${RESULTS_DIR}"

echo "=========================================="
echo "批量测试 Page Size: ${PAGE_SIZES}"
echo "=========================================="
echo "模型: ${MODEL}"
echo "结果目录: ${RESULTS_DIR}"
echo ""

for PAGE_SIZE in ${PAGE_SIZES}; do
  echo ""
  echo "=========================================="
  echo "测试 Page Size: ${PAGE_SIZE}"
  echo "=========================================="
  
  # 使用优化脚本测试
  ./run_benchmark_optimized.sh "${PAGE_SIZE}" "pagesize_test"
  
  # 移动结果文件到 results 目录
  if ls pagesize_test_page${PAGE_SIZE}_*.jsonl 1> /dev/null 2>&1; then
    mv pagesize_test_page${PAGE_SIZE}_*.jsonl "${RESULTS_DIR}/"
    echo "结果已移动到 ${RESULTS_DIR}/"
  fi
  
  echo "完成 Page Size ${PAGE_SIZE}"
  echo ""
done

echo "=========================================="
echo "所有测试完成！"
echo "=========================================="
echo "结果保存在: ${RESULTS_DIR}/"
echo ""
echo "查看汇总结果："
echo "  python3 aggregate_results.py ${RESULTS_DIR}"
