#!/usr/bin/env python3
"""Run `sglang.bench_one_batch` with deterministic Python and NumPy RNG seeds."""

import os
import random
import runpy
import sys

import numpy as np


def get_seed() -> int:
    value = os.environ.get("BENCHMARK_SEED", "20260331")
    try:
        return int(value)
    except ValueError as exc:
        raise SystemExit(f"Invalid BENCHMARK_SEED: {value}") from exc


def main() -> None:
    seed = get_seed()
    random.seed(seed)
    np.random.seed(seed)
    sys.argv[0] = "sglang.bench_one_batch"
    runpy.run_module("sglang.bench_one_batch", run_name="__main__")


if __name__ == "__main__":
    main()
