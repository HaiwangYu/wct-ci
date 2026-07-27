#!/usr/bin/env python3
"""Plot CPU% and memory (GB) vs time for one or more top.sh sample logs.

Each input is a top.sh log of "cpu_pct mem_pct" lines (space-separated).
Time axis = wall-clock elapsed time / number of samples (uniform spacing).
Memory in GB derived from mem_pct * total_mem_kb (from log.meta).
"""
import sys
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

KB_PER_GB = 1024 * 1024

def parse_meta(meta_path):
    meta = {}
    with open(meta_path) as f:
        for line in f:
            k, _, v = line.strip().partition("=")
            meta[k] = v
    return meta

def load(log_path):
    meta = parse_meta(log_path + ".meta")
    elapsed = float(meta["elapsed_sec"])
    total_kb = int(meta["total_mem_kb"])
    data = np.loadtxt(log_path, dtype=float, delimiter=None)
    if data.ndim == 1:
        data = data.reshape(-1, 2)
    n = data.shape[0]
    t = np.linspace(0, elapsed, n) if n > 1 else np.array([0.0])
    cpu = data[:, 0]
    mem_gb = data[:, 1] / 100.0 * total_kb / KB_PER_GB
    return t, cpu, mem_gb, meta

def main():
    if len(sys.argv) < 4 or len(sys.argv) % 2 == 1:
        print("usage: plot-compare.py <out.png> (<label> <log>)+", file=sys.stderr)
        sys.exit(2)
    out = sys.argv[1]
    pairs = list(zip(sys.argv[2::2], sys.argv[3::2]))

    fig, (ax_cpu, ax_mem) = plt.subplots(2, 1, figsize=(10, 7), sharex=True)
    for label, path in pairs:
        t, cpu, mem_gb, meta = load(path)
        ax_cpu.plot(t, cpu, label=f"{label}  ({meta['elapsed_sec']}s, {meta['samples']} samples)")
        ax_mem.plot(t, mem_gb, label=label)
        print(f"{label}: elapsed={meta['elapsed_sec']}s samples={meta['samples']} "
              f"peak_cpu={cpu.max():.1f}% peak_mem={mem_gb.max():.2f} GB")

    ax_cpu.set_ylabel("CPU [%]")
    ax_cpu.grid(True)
    ax_cpu.legend(loc="best", fontsize=9)
    ax_cpu.set_title("`lar -n 1 -c detsim-dom+local.fcl` — memory & CPU vs time")

    ax_mem.set_ylabel("RSS [GB]")
    ax_mem.set_xlabel("time [sec]")
    ax_mem.grid(True)
    ax_mem.legend(loc="best", fontsize=9)

    plt.tight_layout()
    plt.savefig(out, dpi=120)
    print(f"wrote {out}")

if __name__ == "__main__":
    main()
