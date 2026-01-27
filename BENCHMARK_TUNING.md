# Benchmark 参数调优指南 - 突出 Page Size 影响

## 当前问题分析

从之前的测试结果看，Page Size 1 和 16 的性能差异很小（<1%），主要原因：

1. **请求堆积严重**：配置 50 req/s，实际只能处理 1 req/s
2. **并发过高**：128 并发导致大量请求排队
3. **随机数据无重复**：prefix cache 无法发挥作用
4. **输入长度不匹配**：512 tokens 对不同 page_size 的影响不同

## 优化策略

### 1. 降低并发数（最重要）

**原理**：高并发会导致请求堆积，掩盖 page_size 的真实性能差异

**建议值**：
- 轻负载测试：`MAX_CONCURRENCY=8`
- 中等负载：`MAX_CONCURRENCY=16`
- 高负载：`MAX_CONCURRENCY=32`

**使用方法**：
```bash
MAX_CONCURRENCY=16 ./run_benchmark.sh
```

### 2. 降低请求速率

**原理**：让服务器能跟上请求速率，避免堆积

**建议值**：
- 保守：`REQUEST_RATE=2` （2 req/s）
- 适中：`REQUEST_RATE=3-5` （3-5 req/s）
- 激进：`REQUEST_RATE=10` （10 req/s，需根据实际吞吐量调整）

**使用方法**：
```bash
REQUEST_RATE=3 ./run_benchmark.sh
```

### 3. 调整输入长度为 page_size 的倍数

**原理**：让不同 page_size 都能充分利用整页，突出差异

**建议**：
- page_size=1: 输入长度 512 (512页)
- page_size=16: 输入长度 512 (32页) 或 1024 (64页)
- page_size=64: 输入长度 512 (8页) 或 1024 (16页)
- page_size=128: 输入长度 512 (4页) 或 1024 (8页)

**使用方法**：
```bash
# 对于 page_size=16，使用 512 tokens (32页)
RANDOM_INPUT_LEN=512 ./run_benchmark.sh

# 对于 page_size=64，使用 1024 tokens (16页)
RANDOM_INPUT_LEN=1024 ./run_benchmark.sh
```

### 4. 使用优化脚本（推荐）

使用 `run_benchmark_optimized.sh`，自动根据 page_size 调整输入长度：

```bash
# 测试 page_size=16
./run_benchmark_optimized.sh 16

# 测试 page_size=64
./run_benchmark_optimized.sh 64
```

### 5. 增加请求数量

**原理**：更多请求让 prefix cache 有更多命中机会

**建议值**：`NUM_PROMPTS=1000-2000`

### 6. 使用有重复前缀的数据集（如果可用）

**原理**：prefix cache 需要重复的前缀才能发挥作用

**选项**：
- `DATASET=sharegpt`：使用 ShareGPT 数据集（有真实对话，可能有重复前缀）
- `DATASET=random`：随机数据，无重复（当前使用）

## 推荐的测试配置

### 配置 A：轻负载，突出小 page_size 优势
```bash
MAX_CONCURRENCY=8 \
REQUEST_RATE=2 \
NUM_PROMPTS=1000 \
RANDOM_INPUT_LEN=512 \
RANDOM_OUTPUT_LEN=128 \
./run_benchmark.sh
```

### 配置 B：中等负载，平衡测试
```bash
MAX_CONCURRENCY=16 \
REQUEST_RATE=3 \
NUM_PROMPTS=1000 \
RANDOM_INPUT_LEN=1024 \
RANDOM_OUTPUT_LEN=128 \
./run_benchmark.sh
```

### 配置 C：使用优化脚本（最简单）
```bash
# 测试不同 page_size
./run_benchmark_optimized.sh 1
./run_benchmark_optimized.sh 16
./run_benchmark_optimized.sh 64
./run_benchmark_optimized.sh 128
```

## 预期效果

优化后，你应该能看到：

1. **吞吐量差异**：大 page_size（如 64、128）应该比小 page_size（如 1）有更高的吞吐量
2. **延迟差异**：小 page_size 的首 token 延迟可能更低（prefix cache 命中更细粒度）
3. **实际吞吐量接近配置值**：如果配置 3 req/s，实际应该能达到 2-3 req/s

## 监控指标

关注以下指标的变化：

- **请求吞吐量 (req/s)**：应该接近配置的 REQUEST_RATE
- **输出吞吐量 (tok/s)**：大 page_size 应该更高
- **平均端到端延迟**：应该显著降低（从 100+ 秒降到几秒）
- **平均首 token 延迟**：应该显著降低
- **平均 token 间延迟**：应该稳定在较低值

## 故障排查

如果优化后仍然看不到差异：

1. **检查服务器是否正常**：确保服务器没有其他负载
2. **检查 GPU 利用率**：`nvidia-smi` 查看 GPU 是否满载
3. **进一步降低并发**：尝试 `MAX_CONCURRENCY=4`
4. **检查实际吞吐量**：如果实际吞吐量远低于配置，说明服务器是瓶颈
5. **尝试不同输入长度**：测试 256、512、1024、2048 tokens
