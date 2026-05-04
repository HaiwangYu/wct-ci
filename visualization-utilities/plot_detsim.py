#!/usr/bin/env python3
"""Visualize artROOT detsim files: SimChannels and recob::Wire 2D/1D.

Default: opens a window with two 2D heatmaps (SimChannels + Wire).

With --interactive: adds a 1D waveform panel below; click on either 2D
  plot to display the waveform for that channel.

With --out-prefix PREFIX: saves PDFs and .npy arrays, no GUI.

Example:
  python plot_detsim.py --input ../dune/dune10kt-vd/detsim.root \\
      --channel-min 0 --channel-max 2000 --tick-min 0 --tick-max 4095

  python plot_detsim.py --input ../dune/dune10kt-vd/detsim.root \\
      --channel-min 0 --channel-max 2000 --interactive
"""

import argparse
import sys
from collections import defaultdict

import numpy as np
import matplotlib.pyplot as plt

DEFAULT_INPUT = "dune/dune10kt-vd/detsim.root"
DEFAULT_SIMCH_BRANCH = "sim::SimChannels_tpcrawdecoder_simpleSC_detsim.obj"
DEFAULT_WIRE_TAG = "gauss"
_WIRE_BRANCH_TEMPLATE = "recob::Wires_tpcrawdecoder_{tag}_detsim.obj"

# Warn if the dense array would exceed this many elements
_ARRAY_WARN_LIMIT = 500_000_000


def parse_args():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("--input", default=DEFAULT_INPUT, help="artROOT file path")
    p.add_argument("--entry", type=int, default=0, help="Events tree entry (default 0)")
    p.add_argument(
        "--simch-branch",
        default=DEFAULT_SIMCH_BRANCH,
        help="SimChannels branch name in Events TTree",
    )
    p.add_argument(
        "--wire-tag",
        default=DEFAULT_WIRE_TAG,
        metavar="TAG",
        help="recob::Wire product instance tag: gauss|wiener|dnnsp (default: gauss)",
    )
    p.add_argument(
        "--wire-branch",
        default=None,
        help="Override wire branch name directly (overrides --wire-tag)",
    )
    p.add_argument("--channel-min", type=int, default=None, metavar="N")
    p.add_argument("--channel-max", type=int, default=None, metavar="N")
    p.add_argument("--tick-min", type=int, default=None, metavar="N")
    p.add_argument("--tick-max", type=int, default=None, metavar="N")
    p.add_argument(
        "--vmax-percentile",
        type=float,
        default=99.0,
        help="Percentile of non-zero values used for auto vmax (default 99.0)",
    )
    p.add_argument("--cmap", default="YlOrRd", help="Matplotlib colormap (default YlOrRd)")
    p.add_argument(
        "--interactive",
        action="store_true",
        help="Enable click-to-show-1D waveform mode (adds a third panel below the 2D plots)",
    )
    p.add_argument(
        "--out-prefix",
        default=None,
        metavar="PREFIX",
        help="Save PREFIX_simch.pdf / PREFIX_wire.pdf / .npy instead of opening a GUI",
    )
    return p.parse_args()


def import_root():
    try:
        import ROOT  # noqa: PLC0415

        ROOT.gErrorIgnoreLevel = ROOT.kWarning
        return ROOT
    except ImportError:
        sys.exit("PyROOT not available — source your LArSoft/DUNE setup first.")


def open_tree(ROOT, filename):
    f = ROOT.TFile.Open(filename)
    if not f or f.IsZombie():
        sys.exit(f"Cannot open file: {filename}")
    tree = f.Get("Events")
    if not tree:
        sys.exit(f"No 'Events' TTree found in {filename}")
    return f, tree


def _vec_to_numpy(vec):
    """Convert a ROOT std::vector<float> to a numpy array efficiently."""
    try:
        return np.frombuffer(vec.data(), dtype=np.float32, count=vec.size()).copy()
    except Exception:
        return np.array([vec[j] for j in range(vec.size())], dtype=np.float32)


def read_simchannels(ROOT, tree, branch, entry, ch_min, ch_max, tick_min, tick_max):
    """Return sparse dict {channel: {tdc: total_electrons}}."""
    reader = ROOT.TTreeReader(tree)
    simchs = ROOT.TTreeReaderArray("sim::SimChannel")(reader, branch)
    # SetEntry returns kEntryValid=0 on success; treat any non-zero as failure
    if reader.SetEntry(entry) != 0:
        sys.exit(f"Entry {entry} not found; SimChannels branch: {branch!r}")

    deposits = defaultdict(lambda: defaultdict(float))
    n = simchs.GetSize()
    print(f"  SimChannels: {n} objects in branch", file=sys.stderr)

    for i in range(n):
        sc = simchs.At(i)
        ch = int(sc.Channel())
        if ch_min is not None and ch < ch_min:
            continue
        if ch_max is not None and ch > ch_max:
            continue
        for pair in sc.TDCIDEMap():
            tdc = int(pair.first)
            if tick_min is not None and tdc < tick_min:
                continue
            if tick_max is not None and tdc > tick_max:
                continue
            charge = sum(ide.numElectrons for ide in pair.second)
            deposits[ch][tdc] += charge

    print(f"  SimChannels: {len(deposits)} channels with deposits after filter", file=sys.stderr)
    return deposits


def read_wires(ROOT, tree, branch, entry, ch_min, ch_max):
    """Return dict {channel: np.ndarray} with full signal per channel (unfiltered in tick)."""
    reader = ROOT.TTreeReader(tree)
    wires = ROOT.TTreeReaderArray("recob::Wire")(reader, branch)
    if reader.SetEntry(entry) != 0:
        sys.exit(f"Entry {entry} not found; Wire branch: {branch!r}")

    wire_data = {}
    n = wires.GetSize()
    print(f"  recob::Wire: {n} objects in branch", file=sys.stderr)

    for i in range(n):
        w = wires.At(i)
        ch = int(w.Channel())
        if ch_min is not None and ch < ch_min:
            continue
        if ch_max is not None and ch > ch_max:
            continue
        wire_data[ch] = _vec_to_numpy(w.Signal())

    print(f"  recob::Wire: {len(wire_data)} channels after filter", file=sys.stderr)
    return wire_data


def choose_range(label, req_min, req_max, values):
    lo = req_min if req_min is not None else int(min(values))
    hi = req_max if req_max is not None else int(max(values))
    print(f"  {label} range: [{lo}, {hi}]", file=sys.stderr)
    return lo, hi


def build_simch_array(deposits, ch_range, tick_range):
    ch_lo, ch_hi = ch_range
    tick_lo, tick_hi = tick_range
    nch = ch_hi - ch_lo + 1
    ntick = tick_hi - tick_lo + 1
    _warn_size(nch, ntick)
    arr = np.zeros((nch, ntick), dtype=np.float64)
    for ch, tdc_map in deposits.items():
        ci = ch - ch_lo
        if ci < 0 or ci >= nch:
            continue
        for tdc, charge in tdc_map.items():
            ti = tdc - tick_lo
            if 0 <= ti < ntick:
                arr[ci, ti] += charge
    return arr


def build_wire_array(wire_data, ch_range, tick_range):
    ch_lo, ch_hi = ch_range
    tick_lo, tick_hi = tick_range
    nch = ch_hi - ch_lo + 1
    ntick = tick_hi - tick_lo + 1
    arr = np.zeros((nch, ntick), dtype=np.float32)
    for ch, sig in wire_data.items():
        ci = ch - ch_lo
        if ci < 0 or ci >= nch:
            continue
        src_lo = tick_lo
        src_hi = min(tick_lo + ntick, len(sig))
        if src_lo >= len(sig):
            continue
        length = src_hi - src_lo
        arr[ci, :length] = sig[src_lo:src_hi]
    return arr


def _warn_size(nch, ntick):
    total = nch * ntick
    if total > _ARRAY_WARN_LIMIT:
        mb = total * 8 / 1e6
        print(
            f"  WARNING: array is {nch}×{ntick} = {total:,} elements (~{mb:.0f} MB). "
            "Consider narrowing --channel-min/max or --tick-min/max.",
            file=sys.stderr,
        )


def _auto_vmax(arr, percentile):
    nonzero = arr[arr != 0]
    if len(nonzero) == 0:
        return 1.0
    return float(np.percentile(nonzero, percentile))


def _imshow_kwargs(arr, cmap, vmax_percentile):
    return dict(
        aspect="auto",
        origin="lower",
        cmap=cmap,
        vmin=0.0,
        vmax=_auto_vmax(arr, vmax_percentile),
        interpolation="nearest",
    )


def show_2d_only(simch_arr, wire_arr, ch_range, tick_range, args):
    """Display SimChannels and Wire as two stacked 2D heatmaps, no click handler."""
    ch_lo, ch_hi = ch_range
    tick_lo, tick_hi = tick_range
    extent = [ch_lo - 0.5, ch_hi + 0.5, tick_lo - 0.5, tick_hi + 0.5]

    fig, (ax_sc, ax_wr) = plt.subplots(2, 1, figsize=(14, 8))

    im0 = ax_sc.imshow(
        simch_arr.T, extent=extent, **_imshow_kwargs(simch_arr, args.cmap, args.vmax_percentile)
    )
    fig.colorbar(im0, ax=ax_sc, label="electrons", pad=0.02)
    ax_sc.set_title("sim::SimChannels (simpleSC)")
    ax_sc.set_xlabel("Channel")
    ax_sc.set_ylabel("Tick (TDC)")

    im1 = ax_wr.imshow(
        wire_arr.T, extent=extent, **_imshow_kwargs(wire_arr, args.cmap, args.vmax_percentile)
    )
    fig.colorbar(im1, ax=ax_wr, label=f"ADC — recob::Wire ({args.wire_tag})", pad=0.02)
    ax_wr.set_title(f"recob::Wire ({args.wire_tag})")
    ax_wr.set_xlabel("Channel")
    ax_wr.set_ylabel("Tick")

    fig.suptitle(f"{args.input}  entry={args.entry}  wire={args.wire_tag}", fontsize=10)
    plt.tight_layout()
    plt.show()


def show_interactive(simch_arr, wire_arr, ch_range, tick_range, args):
    ch_lo, ch_hi = ch_range
    tick_lo, tick_hi = tick_range
    extent = [ch_lo - 0.5, ch_hi + 0.5, tick_lo - 0.5, tick_hi + 0.5]
    tick_axis = np.arange(tick_lo, tick_hi + 1)

    fig, axes = plt.subplots(
        3, 1, figsize=(14, 11), gridspec_kw={"height_ratios": [2, 2, 1.2]}
    )
    ax_sc, ax_wr, ax_1d = axes

    im0 = ax_sc.imshow(
        simch_arr.T, extent=extent, **_imshow_kwargs(simch_arr, args.cmap, args.vmax_percentile)
    )
    fig.colorbar(im0, ax=ax_sc, label="electrons", pad=0.02)
    ax_sc.set_title("sim::SimChannels (simpleSC)")
    ax_sc.set_xlabel("Channel")
    ax_sc.set_ylabel("Tick (TDC)")

    im1 = ax_wr.imshow(
        wire_arr.T, extent=extent, **_imshow_kwargs(wire_arr, args.cmap, args.vmax_percentile)
    )
    fig.colorbar(im1, ax=ax_wr, label=f"ADC — recob::Wire ({args.wire_tag})", pad=0.02)
    ax_wr.set_title(f"recob::Wire ({args.wire_tag})")
    ax_wr.set_xlabel("Channel")
    ax_wr.set_ylabel("Tick")

    ax_1d.set_title("1D waveform — click on either 2D plot to select channel")
    ax_1d.set_xlabel("Tick")

    vline_sc = ax_sc.axvline(x=ch_lo, color="cyan", lw=0.8, ls="--", visible=False)
    vline_wr = ax_wr.axvline(x=ch_lo, color="cyan", lw=0.8, ls="--", visible=False)

    twin_state = {"ax2": None}

    def update_1d(ch):
        idx = ch - ch_lo
        if idx < 0 or idx >= simch_arr.shape[0]:
            return

        ax_1d.cla()
        if twin_state["ax2"] is not None:
            try:
                twin_state["ax2"].remove()
            except Exception:
                pass
            twin_state["ax2"] = None

        ax_1d.plot(tick_axis, simch_arr[idx], color="darkorange", lw=0.9,
                   label=f"SimCh ch={ch}")
        ax_1d.set_ylabel("electrons", color="darkorange")
        ax_1d.tick_params(axis="y", labelcolor="darkorange")

        ax2 = ax_1d.twinx()
        twin_state["ax2"] = ax2
        ax2.plot(tick_axis, wire_arr[idx], color="steelblue", lw=0.9,
                 label=f"Wire ({args.wire_tag}) ch={ch}")
        ax2.set_ylabel(f"ADC ({args.wire_tag})", color="steelblue")
        ax2.tick_params(axis="y", labelcolor="steelblue")

        ax_1d.set_title(f"Channel {ch}")
        ax_1d.set_xlabel("Tick")

        # Combined legend
        lines1, labels1 = ax_1d.get_legend_handles_labels()
        lines2, labels2 = ax2.get_legend_handles_labels()
        ax_1d.legend(lines1 + lines2, labels1 + labels2, loc="upper right", fontsize=8)

        for vl, xval in [(vline_sc, ch), (vline_wr, ch)]:
            vl.set_xdata([xval, xval])
            vl.set_visible(True)

        fig.canvas.draw_idle()

    def on_click(event):
        if event.inaxes not in (ax_sc, ax_wr):
            return
        if event.xdata is None:
            return
        ch = int(round(event.xdata))
        ch = max(ch_lo, min(ch_hi, ch))
        update_1d(ch)

    fig.canvas.mpl_connect("button_press_event", on_click)
    fig.suptitle(
        f"{args.input}  entry={args.entry}  wire={args.wire_tag}", fontsize=10
    )
    plt.tight_layout()
    plt.show()


def save_static(simch_arr, wire_arr, ch_range, tick_range, args):
    ch_lo, ch_hi = ch_range
    tick_lo, tick_hi = tick_range
    extent = [ch_lo - 0.5, ch_hi + 0.5, tick_lo - 0.5, tick_hi + 0.5]
    prefix = args.out_prefix

    panels = [
        (simch_arr, "simch_simpleSC", "electrons"),
        (wire_arr, f"wire_{args.wire_tag}", f"ADC ({args.wire_tag})"),
    ]
    for arr, label, unit in panels:
        fig, ax = plt.subplots(figsize=(14, 5))
        im = ax.imshow(
            arr.T, extent=extent, **_imshow_kwargs(arr, args.cmap, args.vmax_percentile)
        )
        fig.colorbar(im, ax=ax, label=unit)
        ax.set_title(label)
        ax.set_xlabel("Channel")
        ax.set_ylabel("Tick")
        fig.suptitle(f"{args.input}  entry={args.entry}", fontsize=9)
        plt.tight_layout()
        pdf_path = f"{prefix}_{label}.pdf"
        npy_path = f"{prefix}_{label}.npy"
        fig.savefig(pdf_path, dpi=150, bbox_inches="tight")
        plt.close(fig)
        np.save(npy_path, arr)
        print(f"Saved {pdf_path}  {npy_path}", file=sys.stderr)


def main():
    args = parse_args()
    wire_branch = args.wire_branch or _WIRE_BRANCH_TEMPLATE.format(tag=args.wire_tag)

    ROOT = import_root()
    f, tree = open_tree(ROOT, args.input)

    print("Reading SimChannels...", file=sys.stderr)
    deposits = read_simchannels(
        ROOT, tree, args.simch_branch, args.entry,
        args.channel_min, args.channel_max, args.tick_min, args.tick_max,
    )

    print("Reading recob::Wire...", file=sys.stderr)
    wire_data = read_wires(
        ROOT, tree, wire_branch, args.entry,
        args.channel_min, args.channel_max,
    )

    all_chs = list(deposits.keys()) + list(wire_data.keys())
    if not all_chs:
        sys.exit("No channels found in the requested range.")

    all_tdcs = [tdc for d in deposits.values() for tdc in d]
    wire_ticks = [len(sig) - 1 for sig in wire_data.values() if len(sig) > 0]

    ch_range = choose_range("channel", args.channel_min, args.channel_max, all_chs)

    # Determine tick range: prefer user limits; fall back to data extents
    tick_values = (all_tdcs or [0]) + (
        [args.tick_min or 0] + ([max(wire_ticks)] if wire_ticks else [])
    )
    tick_range = choose_range("tick", args.tick_min, args.tick_max, tick_values)

    print("Building dense arrays...", file=sys.stderr)
    simch_arr = build_simch_array(deposits, ch_range, tick_range)
    wire_arr = build_wire_array(wire_data, ch_range, tick_range)

    if args.out_prefix:
        save_static(simch_arr, wire_arr, ch_range, tick_range, args)
    elif args.interactive:
        show_interactive(simch_arr, wire_arr, ch_range, tick_range, args)
    else:
        show_2d_only(simch_arr, wire_arr, ch_range, tick_range, args)

    f.Close()


if __name__ == "__main__":
    main()
