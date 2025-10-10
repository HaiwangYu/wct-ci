#!/usr/bin/env python3
"""
Compare a 1D slice along the Y axis from a 2D histogram stored in one or more ROOT files.

Defaults target the protodune datasets given in the cheatsheet, but everything may be
customised via CLI flags.
"""

from __future__ import annotations

import argparse
from itertools import cycle
from pathlib import Path
from typing import List, Tuple

import matplotlib.pyplot as plt
import numpy as np
import uproot


def parse_args() -> argparse.Namespace:
    base_dir = Path(__file__).resolve().parent

    parser = argparse.ArgumentParser(
        description="Compare a Y-axis slice of a 2D histogram from multiple ROOT files."
    )
    parser.add_argument(
        "--files",
        type=Path,
        nargs="+",
        default=[
            # base_dir / "test5" / "magnify-protodunehd_hk.root",
            # base_dir / "test6" / "magnify-protodunehd_hk.root",
            # base_dir / "test11" / "magnify-protodunehd_hk.root",
            # base_dir / "test12" / "magnify-protodunehd_hk.root",
            base_dir / "test13.root",
            base_dir / "test14.root",
        ],
        help="List of ROOT files to include in the comparison (default paths inside rand-debug)",
    )
    parser.add_argument(
        "--hist-name",
        default="hu_orig0",
        help="Name of the 2D histogram inside the ROOT files (default: %(default)s)",
    )
    parser.add_argument(
        "--channel",
        type=float,
        default=104.0,
        help="Channel value (X-axis) used to extract the slice (default: %(default)s)",
    )
    parser.add_argument(
        "--tick-min",
        type=float,
        default=4300.0,
        help="Lower tick boundary on the Y-axis (default: %(default)s)",
    )
    parser.add_argument(
        "--tick-max",
        type=float,
        default=4500.0,
        help="Upper tick boundary on the Y-axis (default: %(default)s)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=base_dir / "hist_slice_comparison.png",
        help="Filename for the saved PNG image (default: %(default)s)",
    )
    return parser.parse_args()


def load_histogram_slice(
    file_path: Path, hist_name: str, channel_value: float, tick_bounds: Tuple[float, float]
) -> Tuple[np.ndarray, np.ndarray]:
    """Return Y-axis bin centers and values for the requested slice."""
    if not file_path.exists():
        raise FileNotFoundError(f"Could not find ROOT file: {file_path}")

    with uproot.open(file_path) as root_file:
        if hist_name not in root_file:
            available = ", ".join(root_file.keys())
            raise KeyError(
                f"Histogram '{hist_name}' not found in {file_path} "
                f"(available objects: {available})"
            )

        hist = root_file[hist_name]
        values, x_edges, y_edges = hist.to_numpy(flow=False)

    x_centers = 0.5 * (x_edges[:-1] + x_edges[1:])
    y_centers = 0.5 * (y_edges[:-1] + y_edges[1:])

    # Find the x-bin that contains the requested channel value.
    x_index = np.searchsorted(x_edges, channel_value, side="right") - 1
    if x_index < 0 or x_index >= values.shape[0]:
        raise ValueError(
            f"Channel {channel_value} falls outside histogram X range "
            f"[{x_edges[0]}, {x_edges[-1]}]"
        )

    y_min, y_max = tick_bounds
    if y_min > y_max:
        raise ValueError("tick-min must be <= tick-max")

    y_mask = (y_centers >= y_min) & (y_centers <= y_max)
    if not np.any(y_mask):
        raise ValueError(
            f"No Y bins found within tick bounds [{y_min}, {y_max}] "
            f"(histogram Y range is [{y_centers.min()}, {y_centers.max()}])."
        )

    return y_centers[y_mask], values[x_index, y_mask]


def main() -> None:
    args = parse_args()
    tick_bounds = (args.tick_min, args.tick_max)

    if not args.files:
        raise ValueError("Provide at least one ROOT file via --files to perform a comparison.")

    y_ref: np.ndarray | None = None
    slices: List[Tuple[Path, np.ndarray]] = []

    for file_path in args.files:
        y_vals, slice_vals = load_histogram_slice(
            file_path, args.hist_name, args.channel, tick_bounds
        )
        if y_ref is None:
            y_ref = y_vals
        elif not np.allclose(y_ref, y_vals):
            raise RuntimeError(
                f"Y bin centers differ between histograms. "
                f"Mismatch detected for {file_path}."
            )
        slices.append((file_path, slice_vals))

    assert y_ref is not None  # for mypy-like tools

    plt.figure(figsize=(8, 5))

    marker_cycle = cycle(["o", "s", "^", "D", "v", "P", "X"])
    for file_path, slice_vals in slices:
        marker = next(marker_cycle)
        plt.plot(y_ref, slice_vals, label=file_path.name, marker=marker, linestyle="-")

    plt.title(
        f"{args.hist_name} slice @ channel {args.channel} "
        f"({args.tick_min:.0f} ≤ ticks ≤ {args.tick_max:.0f})"
    )
    plt.xlabel("Tick")
    plt.ylabel("Bin content")
    plt.legend()
    plt.grid(True, alpha=0.3)

    output_path = args.output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    print(f"Saved comparison plot to {output_path}")

    plt.show()


if __name__ == "__main__":
    main()
