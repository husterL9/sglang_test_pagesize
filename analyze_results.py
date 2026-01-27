#!/usr/bin/env python3
"""分析 results/ 目录中的 benchmark 结果，按 page_size 对比性能指标"""
import json
import sys
from pathlib import Path
from collections import defaultdict
from datetime import datetime

def parse_filename(filename):
    """从文件名解析 page_size 和时间戳"""
    # bench_page16_20260127_132450.jsonl -> (16, 20260127_132450)
    name = Path(filename).stem
    if "page" in name:
        try:
            rest = name.split("page", 1)[1]
            parts = rest.split("_")
            ps = int(parts[0])
            timestamp = "_".join(parts[1:3]) if len(parts) >= 3 else None
            return ps, timestamp
        except (IndexError, ValueError):
            pass
    return None, None

def load_results(results_dir):
    """加载所有结果文件"""
    results_dir = Path(results_dir)
    if not results_dir.exists():
        print(f"目录不存在: {results_dir}")
        sys.exit(1)
    
    all_results = defaultdict(list)
    
    for f in sorted(results_dir.glob("bench_*.jsonl")):
        page_size, timestamp = parse_filename(f.name)
        if page_size is None:
            continue
        
        try:
            # 读取最后一行（汇总结果）
            with open(f, 'r') as file:
                lines = [line.strip() for line in file if line.strip()]
                if not lines:
                    continue
                # 取最后一行（通常是汇总结果）
                data = json.loads(lines[-1])
                
                result = {
                    "page_size": page_size,
                    "timestamp": timestamp,
                    "file": f.name,
                    "request_throughput": data.get("request_throughput"),
                    "output_throughput": data.get("output_throughput"),
                    "input_throughput": data.get("input_throughput"),
                    "total_throughput": data.get("total_throughput"),
                    "mean_e2e_latency_ms": data.get("mean_e2e_latency_ms"),
                    "median_e2e_latency_ms": data.get("median_e2e_latency_ms"),
                    "p90_e2e_latency_ms": data.get("p90_e2e_latency_ms"),
                    "p99_e2e_latency_ms": data.get("p99_e2e_latency_ms"),
                    "mean_ttft_ms": data.get("mean_ttft_ms"),
                    "median_ttft_ms": data.get("median_ttft_ms"),
                    "p99_ttft_ms": data.get("p99_ttft_ms"),
                    "mean_itl_ms": data.get("mean_itl_ms"),
                    "median_itl_ms": data.get("median_itl_ms"),
                    "p99_itl_ms": data.get("p99_itl_ms"),
                }
                all_results[page_size].append(result)
        except (json.JSONDecodeError, KeyError) as e:
            print(f"警告: 无法解析 {f.name}: {e}")
            continue
    
    return all_results

def select_best_result(results):
    """对于每个 page_size，选择最新的结果（或最好的结果）"""
    best_results = {}
    for page_size, result_list in results.items():
        if not result_list:
            continue
        # 选择最新的结果（按时间戳）
        best = max(result_list, key=lambda x: x.get("timestamp", ""))
        best_results[page_size] = best
    return best_results

def print_summary_table(results):
    """打印汇总对比表格"""
    print("=" * 100)
    print("Page Size 性能对比汇总")
    print("=" * 100)
    print()
    
    # 表头
    header = f"{'Page Size':<12} {'请求吞吐量':<12} {'输出吞吐量':<14} {'端到端延迟':<16} {'首Token延迟':<16} {'Token间延迟':<16}"
    print(header)
    print("-" * len(header))
    
    # 按 page_size 排序
    for ps in sorted(results.keys()):
        r = results[ps]
        req_t = r.get("request_throughput", 0)
        out_t = r.get("output_throughput", 0)
        e2e = r.get("mean_e2e_latency_ms", 0)
        ttft = r.get("mean_ttft_ms", 0)
        itl = r.get("mean_itl_ms", 0)
        
        line = f"{ps:<12} {req_t:<12.2f} {out_t:<14.2f} {e2e:<16.2f} {ttft:<16.2f} {itl:<16.2f}"
        print(line)
    
    print()

def print_detailed_table(results):
    """打印详细对比表格"""
    print("=" * 120)
    print("详细性能指标对比")
    print("=" * 120)
    print()
    
    # 表头
    header = (
        f"{'Page Size':<12} {'请求/s':<10} {'输出tok/s':<12} {'输入tok/s':<12} "
        f"{'E2E均值':<12} {'E2E中位':<12} {'E2E P90':<12} {'E2E P99':<12} "
        f"{'TTFT均值':<12} {'TTFT中位':<12} {'ITL均值':<12} {'ITL中位':<12}"
    )
    print(header)
    print("-" * len(header))
    
    for ps in sorted(results.keys()):
        r = results[ps]
        line = (
            f"{ps:<12} "
            f"{r.get('request_throughput', 0):<10.2f} "
            f"{r.get('output_throughput', 0):<12.2f} "
            f"{r.get('input_throughput', 0):<12.2f} "
            f"{r.get('mean_e2e_latency_ms', 0):<12.2f} "
            f"{r.get('median_e2e_latency_ms', 0):<12.2f} "
            f"{r.get('p90_e2e_latency_ms', 0):<12.2f} "
            f"{r.get('p99_e2e_latency_ms', 0):<12.2f} "
            f"{r.get('mean_ttft_ms', 0):<12.2f} "
            f"{r.get('median_ttft_ms', 0):<12.2f} "
            f"{r.get('mean_itl_ms', 0):<12.2f} "
            f"{r.get('median_itl_ms', 0):<12.2f}"
        )
        print(line)
    
    print()

def print_analysis(results):
    """打印分析结论"""
    print("=" * 100)
    print("性能分析")
    print("=" * 100)
    print()
    
    if len(results) < 2:
        print("结果不足，无法进行对比分析")
        return
    
    sorted_ps = sorted(results.keys())
    
    # 找出最佳性能
    best_req_throughput = max(sorted_ps, key=lambda ps: results[ps].get("request_throughput", 0))
    best_out_throughput = max(sorted_ps, key=lambda ps: results[ps].get("output_throughput", 0))
    best_e2e_latency = min(sorted_ps, key=lambda ps: results[ps].get("mean_e2e_latency_ms", float('inf')))
    best_ttft = min(sorted_ps, key=lambda ps: results[ps].get("mean_ttft_ms", float('inf')))
    best_itl = min(sorted_ps, key=lambda ps: results[ps].get("mean_itl_ms", float('inf')))
    
    print(f"最佳请求吞吐量: Page Size {best_req_throughput} ({results[best_req_throughput].get('request_throughput', 0):.2f} req/s)")
    print(f"最佳输出吞吐量: Page Size {best_out_throughput} ({results[best_out_throughput].get('output_throughput', 0):.2f} tok/s)")
    print(f"最低端到端延迟: Page Size {best_e2e_latency} ({results[best_e2e_latency].get('mean_e2e_latency_ms', 0):.2f} ms)")
    print(f"最低首Token延迟: Page Size {best_ttft} ({results[best_ttft].get('mean_ttft_ms', 0):.2f} ms)")
    print(f"最低Token间延迟: Page Size {best_itl} ({results[best_itl].get('mean_itl_ms', 0):.2f} ms)")
    print()
    
    # 计算相对于 page_size=1 的改进
    if 1 in results:
        baseline = results[1]
        print("相对于 Page Size 1 的性能变化:")
        print("-" * 80)
        for ps in sorted_ps:
            if ps == 1:
                continue
            r = results[ps]
            req_change = ((r.get("request_throughput", 0) - baseline.get("request_throughput", 0)) / 
                         baseline.get("request_throughput", 1) * 100) if baseline.get("request_throughput", 0) > 0 else 0
            out_change = ((r.get("output_throughput", 0) - baseline.get("output_throughput", 0)) / 
                         baseline.get("output_throughput", 1) * 100) if baseline.get("output_throughput", 0) > 0 else 0
            e2e_change = ((baseline.get("mean_e2e_latency_ms", 0) - r.get("mean_e2e_latency_ms", 0)) / 
                          baseline.get("mean_e2e_latency_ms", 1) * 100) if baseline.get("mean_e2e_latency_ms", 0) > 0 else 0
            
            print(f"Page Size {ps}: "
                  f"请求吞吐量 {req_change:+.1f}%, "
                  f"输出吞吐量 {out_change:+.1f}%, "
                  f"端到端延迟 {e2e_change:+.1f}%")
        print()

def main(results_dir="results", detailed=False):
    """主函数"""
    print(f"分析目录: {results_dir}")
    print()
    
    # 加载结果
    all_results = load_results(results_dir)
    
    if not all_results:
        print("未找到任何结果文件")
        return
    
    # 选择每个 page_size 的最佳结果（最新）
    best_results = select_best_result(all_results)
    
    # 打印汇总表格
    print_summary_table(best_results)
    
    # 打印详细表格
    if detailed:
        print_detailed_table(best_results)
    
    # 打印分析
    print_analysis(best_results)
    
    # 列出所有结果文件
    print("=" * 100)
    print("所有结果文件:")
    print("=" * 100)
    for ps in sorted(all_results.keys()):
        print(f"\nPage Size {ps}:")
        for r in all_results[ps]:
            timestamp = r.get("timestamp", "unknown")
            req_t = r.get("request_throughput", 0)
            print(f"  {r['file']} (时间: {timestamp}, 请求吞吐量: {req_t:.2f} req/s)")

if __name__ == "__main__":
    detailed = "--detailed" in sys.argv or "-d" in sys.argv
    results_dir = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else "results"
    main(results_dir, detailed)
