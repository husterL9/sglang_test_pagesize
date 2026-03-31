#!/usr/bin/env python3
"""汇总 bench_one_batch 的 page_size 结果。"""

import json
import sys
from pathlib import Path


def extract_page_size(path: Path):
    name = path.stem
    if "page" not in name:
        return None
    try:
        rest = name.split("page", 1)[1]
        return int(rest.split("_")[0])
    except (IndexError, ValueError):
        return None


def iter_jsonl_records(path: Path):
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return

    for line in content.splitlines():
        if not line.strip():
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue


def format_value(value, digits=1, scale=1.0):
    if value is None:
        return "-"
    return f"{value * scale:.{digits}f}"


def load_rows(results_dir: Path):
    rows = []
    for path in sorted(results_dir.glob("one_batch_*.jsonl")):
        page_size = extract_page_size(path)
        for record in iter_jsonl_records(path):
            rows.append(
                {
                    "page_size": page_size,
                    "batch_size": record.get("batch_size"),
                    "input_len": record.get("input_len"),
                    "output_len": record.get("output_len"),
                    "prefill_latency_s": record.get("prefill_latency"),
                    "prefill_tok_per_s": record.get("prefill_throughput"),
                    "decode_latency_s": record.get("median_decode_latency"),
                    "decode_tok_per_s": record.get("median_decode_throughput"),
                    "overall_tok_per_s": record.get("overall_throughput"),
                    "file": path.name,
                }
            )
    return rows


def print_rows(rows):
    sep = " | "
    header = sep.join(
        [
            "page_size",
            "batch",
            "input",
            "output",
            "prefill_ms",
            "prefill_tok/s",
            "decode_ms",
            "decode_tok/s",
            "overall_tok/s",
            "file",
        ]
    )
    print(header)
    print("-" * len(header))

    def sort_key(row):
        page_size = row["page_size"]
        return (page_size is None, page_size if page_size is not None else 0, row["file"])

    for row in sorted(rows, key=sort_key):
        page_size = row["page_size"] if row["page_size"] is not None else "?"
        print(
            sep.join(
                [
                    str(page_size),
                    format_value(row["batch_size"], digits=0),
                    format_value(row["input_len"], digits=0),
                    format_value(row["output_len"], digits=0),
                    format_value(row["prefill_latency_s"], digits=2, scale=1000.0),
                    format_value(row["prefill_tok_per_s"], digits=0),
                    format_value(row["decode_latency_s"], digits=2, scale=1000.0),
                    format_value(row["decode_tok_per_s"], digits=0),
                    format_value(row["overall_tok_per_s"], digits=0),
                    row["file"],
                ]
            )
        )


def main(results_dir: str = "results"):
    results_dir_path = Path(results_dir)
    if not results_dir_path.exists():
        print(f"Directory not found: {results_dir_path}")
        sys.exit(1)

    rows = load_rows(results_dir_path)
    if not rows:
        print("No one_batch JSONL records found.")
        return

    print_rows(rows)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "results")
