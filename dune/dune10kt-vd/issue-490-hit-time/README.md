# Issue #490 — FD-VD different minimum hit times by branch

Upstream: https://github.com/WireCell/wire-cell-toolkit/issues/490

**Status: RESOLVED.** This directory holds the investigation and the fix
verification. `README.md` (this file) is the summary; `FINDINGS.md` is the full
chronological investigation trail (including superseded intermediate theories).

## Root cause

The VD **ductor pre-readout opening was 10 cm instead of the 18.92 cm response
plane**. WCT simulates at the response plane, so the ductor (`DepoTransform` /
`sim.ductor` in jsonnet) must open early by `response_plane / drift_speed`, and a
`Reframer` chops that pre-opening back to the DAQ window. The VD config leaked the
generic **10 cm** default (`elec.fields.start_dx`), giving a `-125`-tick opening
instead of the correct **18.92 cm → -236 ticks**. The ~111-tick shortfall is the
"missing hits below tick 100" seen in the issue's reco1 Hit-Peak-Time plot.

| | `start_dx` | `drift_dt` | `ductor.start_time` | `reframer.tbin` |
|---|---|---|---|---|
| buggy default | 10 cm    | 62.28 µs  | -62280 ns (-125 t) | 125 |
| correct        | 18.92 cm | 117.84 µs | -117836 ns (-236 t)| 236 |

`ductor.start_time` and `reframer.tbin` are defined in terms of `elec.fields` in
the base `pgrapher/common/params.jsonnet` (lines 146/151/184/186/194), so the
single lever is `elec.fields.start_dx`.

## The fix

`single-apa` branch of dunereco already fixes VD via a one-line `elec.fields`
override in `DUNEWireCell/dune-vd/params.jsonnet`:

```jsonnet
elec: super.elec {
    ...
    fields: super.fields {
        start_dx: $.det.response_plane,          // 10 cm -> 18.92 cm
        drift_dt: self.start_dx / $.lar.drift_speed,
    },
},
```

This is **equivalent** to the explicit `sim.ductor` + `sim.reframer` block used in
`dune10kt-vd/params-10kt.jsonnet` and `dune10kt-1x2x6/params.jsonnet` (both routes
set the same lever and yield 236 ticks).

**Still buggy (need the same fix):** DUNE/develop (vanilla) and the `smear-dnn`
VD workspace — their `dune-vd/params.jsonnet` lacks the `elec.fields` override.

## Why the early vanilla-vs-branch tests looked "consistent"

The early "rollexp" runs used the local **`smear-dnn`** branch, which does **not**
contain the fix (`git diff smear-dnn..single-apa -- .../dune-vd/params.jsonnet`
is *only* the `elec.fields` addition). So both sides had the same buggy 125-tick
opening → byte-identical `recob::Wire`. The valid comparison is
release/`smear-dnn` (125 t) **vs** `single-apa` (236 t).

## Verification (anode-cathode muon `g4_vd_muminus_tomox_1x8x14.root`, full 1x8x14)

| config | earliest signal tick | bin [0,100) Σ\|gauss\| | Qtot |
|---|---|---|---|
| vanilla (release / smear-dnn, 125 t) | 105 | 0    | 8.796e4 |
| **single-apa (236 t)**               | **0** | **3250** | 9.066e4 (+3.1%) |

Hits below tick 100 are recovered (earliest 105 → 0). Numbers table in
`FIX-comparison.txt`.

## Reproduce

Env wrappers: `setup-vanilla.sh` (pure release) and the rollexp/single-apa setup
`/exp/dune/app/users/yuhw/cffm-if/smear-dnn/setup-smear-dnn.sh` (prepends local
dunereco source — `git checkout single-apa` there to get the fix). All runs go
through `/exp/dune/app/users/yuhw/wct-ci/dune/in-sl7-dom.sh` (SL7 apptainer),
`taskset -c 0-7`, on the muon at
`/exp/dune/app/users/yuhw/wct-ci/dune/dune-vd/g4_vd_muminus_tomox_1x8x14.root`.

- **buggy baseline** (release): `run_van.fcl` / `go_van.sh` → `sp_van.root`
- **fixed** (single-apa branch): `single-apa/run_singleapa.fcl` /
  `single-apa/go_singleapa.sh` → `single-apa/sp_singleapa.root`
- **compare**: `python3 compare2.py sp_van.root single-apa/sp_singleapa.root vanilla singleapa`
  (per-tick Σ|gauss| profile, earliest tick, Qtot, per-100-tick ratios)

### Config dump (evaluate jsonnet → JSON, no sim)

`config-dump/` holds the tooling: `dbg.jsonnet` / `dbg2.jsonnet` evaluate
`params.sim.ductor` / `reframer`; `cmp.py` diffs two full node dumps.
NOTE: gojsonnet searches `-J` paths in **reverse**, so the local branch dir must
be the **last** `-J` to win over the cvmfs release. `DIFF-ductor-reframer.json`
shows the ductor/reframer timing that carries the fix.

## Scripts in this directory (tracked)

- `compare2.py A.root B.root labelA labelB` — per-tick Σ|gauss| profile comparator
  for two `recob::Wire` files (earliest/latest tick, Qtot, per-100-tick ratios).
- `probe_mu.py` — dump the `IonAndScint` SimEnergyDeposit x/t range of a g4 file
  (path hard-coded near the top).
- `probe2.py FILE.root` — same, for a g4 file given as `argv[1]` (x/y/z/t range).
- `config-dump/cmp.py` — diff two evaluated WCT config JSON dumps (node-type
  counts + per-node timing fields).
- `config-dump/dbg.jsonnet`, `config-dump/dbg2.jsonnet` — evaluate
  `params.sim.ductor` / `reframer` for the dune-vd config (see Config dump above).

Generated outputs (`*.root`, `*.log`), env wrappers and run drivers
(`*.sh`, `*.fcl`, `*.json`, `*.jsonnet`) are `.gitignore`d by the repo; the two
canonical outputs `sp_van.root` (buggy) and `single-apa/sp_singleapa.root` (fixed)
are kept on disk for immediate re-verification with `compare2.py`.

## Loglevel side-fix (2026-08-11)

On `single-apa` (uncommitted): `DUNEWireCell/wirecell_dune.fcl` 11× `loglevels:
["debug"] → ["info"]`, and `dune-vd/wcls-sim-drift-simchannel-nf-sp.fcl` line 17
inline `["debug"] → ["info"]` (the sim test reads its loglevel inline, not from
`wirecell_dune.fcl`). Verbosity dropped 6825 → 167 lines (6210 → 0 debug), physics
unchanged. The `["debug", "pgraph:info"]` lines were left untouched.
