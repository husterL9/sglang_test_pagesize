# SGLang 不同 page_size 性能测试（FlashInfer 后端）

在 SGLang 下用 **FlashInfer** 作为 attention 后端，对不同 `--page-size` 做基准测试，便于对比吞吐与延迟。

## 概念简述

- **`--page-size`**：每个 KV cache 块包含的 token 数量，默认 1。FlashInfer 原生支持 page_size > 1。
- **Prefix cache**：只有整页写满才会参与前缀复用。例如 page_size=64、prompt 只有 32 token 时，这一整段不会命中 prefix cache；page_size=1 时复用粒度最细。
- **`--attention-backend flashinfer`**：显式使用 FlashInfer，本仓库所有脚本都带此参数。

## 前置条件

1. 已安装 [SGLang](https://github.com/sgl-project/sglang)（含 FlashInfer）。
2. 至少一张 GPU，显存能跑目标模型（如 Llama-3.1-8B）。
3. 基准测试依赖：`aiohttp`、`numpy`、`requests`、`tqdm`、`transformers`、`datasets`（按需）。

## 目录与脚本

| 文件 | 说明 |
|------|------|
| `start_server.sh` | 用 FlashInfer + 指定 page_size 启动 SGLang 服务 |
| `run_benchmark.sh` | 对已运行的服务执行 `sglang.bench_serving` |
| `sweep_page_sizes.sh` | 自动对多个 page_size 依次：启服 → 跑 bench → 停服，结果写到 `results/` |
| `aggregate_results.py` | 从 `results/*.jsonl` 汇总成表格，便于对比不同 page_size |
| `README.md` | 本说明 |

## 用法

### 方式一：手动测某个 page_size

1. 启动服务（例：page_size=16，默认模型 `meta-llama/Llama-3.1-8B-Instruct`）：
   ```bash
   chmod +x start_server.sh run_benchmark.sh
   ./start_server.sh 16
   ```
2. 另开终端跑基准：
   ```bash
   ./run_benchmark.sh my_run
   ```
   输出会写到当前目录下带时间戳的 `my_run_*.jsonl`。

指定模型与端口示例：
```bash
./start_server.sh 64 /path/to/your/model
# 或
SGLANG_PORT=30001 ./start_server.sh 32
```

跑 benchmark 时若服务不在默认地址，可设环境变量：
```bash
SGLANG_HOST=127.0.0.1 SGLANG_PORT=30001 SGLANG_BENCH_MODEL=meta-llama/Llama-3.1-8B-Instruct ./run_benchmark.sh
```

可通过环境变量改 bench 规模（在 `run_benchmark.sh` 中已有默认）：
- `NUM_PROMPTS`、`REQUEST_RATE`、`MAX_CONCURRENCY`
- `RANDOM_INPUT_LEN`、`RANDOM_OUTPUT_LEN`、`DATASET`

### 方式二：自动 sweep 多个 page_size

一次性对多个 page_size 启服、跑 bench、停服，结果落在 `results/`：

```bash
chmod +x sweep_page_sizes.sh
./sweep_page_sizes.sh
```

默认测试的 page_size：`1 16 32 64 128`。可自定义：

```bash
PAGE_SIZES="1 8 16 32 64" ./sweep_page_sizes.sh
```

指定模型与等待时间（秒）：

```bash
./sweep_page_sizes.sh meta-llama/Llama-3.1-8B-Instruct
WAIT_READY_SEC=180 RESULTS_DIR=./my_results ./sweep_page_sizes.sh
```

生成的文件形如：`results/bench_page16_20250126_120000.jsonl`。

### 汇总结果

sweep 结束后，用表格看各 page_size 的 req/s、output tok/s、e2e/ttft/itl：

```bash
python3 aggregate_results.py
# 或指定目录
python3 aggregate_results.py ./my_results
```

脚本会解析 `results/`（或你给的目录）下 `bench_*.jsonl`，从文件名中的 `page{N}` 读出 page_size，并输出一列表格。

## 如何解读

- **page_size=1**：前缀复用最细，prefix cache 命中率高，但块多、元数据与调度开销大。
- **page_size 增大（如 16、32、64）**：块更大，通常能提高吞吐、有时降低延迟，但若单次请求 token 数远小于 page_size，前缀几乎无法整页复用。
- 建议在同一组 input/output 长度、同一并发下对比不同 page_size 的：
  - `request_throughput`、`output_throughput`
  - `mean_e2e_latency_ms`、`mean_ttft_ms`、`mean_itl_ms`

结合你真实业务里的典型 prompt 长度和并发，选吞吐与延迟更均衡的 page_size。

## 参考

- [SGLang Server Arguments](https://sgl-project.github.io/backend/server_arguments.html)（含 `--page-size`、`--attention-backend`）
- [SGLang Attention Backend](https://sgl-project.github.io/advanced_features/attention_backend.html)（FlashInfer 能力与 page size 说明）
- [SGLang Bench Serving](https://sgl-project.github.io/developer_guide/bench_serving.html)
