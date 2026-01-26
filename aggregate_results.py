#!/usr/bin/env python3
"""从 results/ 下的 bench_*_.jsonl 汇总各 page_size 的吞吐与延迟，便于对比。"""
import json
import sys
from pathlib import Path

def main(results_dir: str = "results"):
    results_dir = Path(results_dir)
    if not results_dir.exists():
        print(f"Directory not found: {results_dir}")
        sys.exit(1)

    rows = []
    for f in sorted(results_dir.glob("bench_*.jsonl")):
        # bench_page16_20250126_120000.jsonl -> page_size=16
        name = f.stem
        if "page" in name:
            try:
                rest = name.split("page", 1)[1]
                ps = int(rest.split("_")[0])
            except (IndexError, ValueError):
                ps = None
        else:
            ps = None

        for line in f.read_text().strip().splitlines():
            if not line.strip():
                continue
            try:
                d = json.loads(line)
                row = {
                    "page_size": ps,
                    "file": f.name,
                    "req_throughput": d.get("request_throughput"),
                    "output_tok_per_s": d.get("output_throughput"),
                    "total_tok_per_s": d.get("total_throughput"),
                    "e2e_latency_mean_ms": d.get("mean_e2e_latency_ms"),
                    "ttft_mean_ms": d.get("mean_ttft_ms"),
                    "itl_mean_ms": d.get("mean_itl_ms"),
                }
                rows.append(row)
            except json.JSONDecodeError:
                continue

    if not rows:
        print("No JSONL records found.")
        return

    # 表头
    sep = " | "
    header = sep.join(["page_size", "req/s", "out_tok/s", "e2e_mean_ms", "ttft_mean_ms", "itl_mean_ms"])
    print(header)
    print("-" * len(header))

    for r in rows:
        ps = r["page_size"] if r["page_size"] is not None else "?"
        req_s = r["req_throughput"]
        tok_s = r["output_tok_per_s"]
        e2e = r["e2e_latency_mean_ms"]
        ttft = r["ttft_mean_ms"]
        itl = r["itl_mean_ms"]
        line = sep.join([
            str(ps),
            f"{req_s:.1f}" if req_s is not None else "-",
            f"{tok_s:.0f}" if tok_s is not None else "-",
            f"{e2e:.0f}" if e2e is not None else "-",
            f"{ttft:.0f}" if ttft is not None else "-",
            f"{itl:.2f}" if itl is not None else "-",
        ])
        print(line)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "results")
