#!/usr/bin/env bash
# 使用 FlashInfer 后端启动 SGLang 服务，可配置 page_size
# 用法: ./start_server.sh [page_size] [model_path]
# 示例: ./start_server.sh 16
#       ./start_server.sh 64 Qwen/Qwen2.5-7B-Instruct
#       ./start_server.sh 16 meta-llama/Llama-3.1-8B-Instruct  # 使用 Llama 模型
#       CUDA_VISIBLE_DEVICES=0 ./start_server.sh 16  # 使用 GPU 0 (RTX 4090，默认)
#       CUDA_VISIBLE_DEVICES=1 ./start_server.sh 16  # 使用 GPU 1 (P100)

set -e

# GPU 选择：默认使用 GPU 0 (RTX 4090)
# 如需使用 GPU 1 (P100) 请设置：export CUDA_VISIBLE_DEVICES=1
# 或者运行时指定：CUDA_VISIBLE_DEVICES=0 ./start_server.sh
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"

PAGE_SIZE="${1:-16}"
MODEL_PATH="${2:-Qwen/Qwen2.5-7B-Instruct}"
PORT="${SGLANG_PORT:-30000}"

# HuggingFace Token：用于访问 gated repositories（如 Llama 模型）
# 获取方式：1) 访问 https://huggingface.co/settings/tokens 创建 token
#          2) 运行：huggingface-cli login
#          3) 或设置环境变量：export HF_TOKEN=your_token_here
# export HF_TOKEN=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

# 注意：gated repositories 需要使用官方源，不能使用镜像
# if [ -n "${HF_TOKEN}" ]; then
#     export HF_TOKEN
#     # gated repositories 需要使用官方源
#     export HF_ENDPOINT="${HF_ENDPOINT:-https://huggingface.co}"
# else
#     # 如果没有 token，默认使用镜像（但 gated repositories 会失败）
#     export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
# fi

# HuggingFace 镜像源配置
# 默认使用镜像源加速下载（适用于公开模型如 Qwen）
# 如果需要访问 gated repositories（如 Llama），可以设置：export HF_ENDPOINT=https://huggingface.co
# 但注意：gated repositories 可能需要能访问官方源
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 增加 HuggingFace 下载超时时间（默认 10 秒可能不够）
# 设置为 300 秒（5 分钟）以应对网络较慢的情况
# export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-300}"
# HF_ENDPOINT=https://huggingface.co
echo "Starting SGLang with:"
echo "  --attention-backend flashinfer"
echo "  --page-size ${PAGE_SIZE}"
echo "  --model-path ${MODEL_PATH}"
echo "  --port ${PORT}"
echo "  --cuda-visible-devices ${CUDA_VISIBLE_DEVICES}"
echo ""

python3 -m sglang.launch_server \
  --model-path "${MODEL_PATH}" \
  --attention-backend flashinfer \
  --download-dir "/root/autodl-tmp/hf_cache/hub" \
  --page-size "${PAGE_SIZE}" \
  --port "${PORT}" \
  "${@:3}"
