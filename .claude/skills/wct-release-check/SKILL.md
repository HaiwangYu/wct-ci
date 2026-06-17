---
name: wct-release-check
description: Build, test, and compare a wire-cell-toolkit ref (e.g. current master) against a baseline release (e.g. a tagged release like 0.36.1) using the ci-utilities, then produce and deliver the comparison report PDF. Optionally also runs a multi-compiler-qualifier UPS packaging build (e26 + c14 prof via the ssibuildshims shim) as an extra pre-release check. Use when the user wants to validate master (or any branch/tag) against a previous release, run a "release check", or get a CI comparison report between two refs of wire-cell-toolkit.
---

# wct-release-check

Runs the local wire-cell-toolkit CI in **ref-vs-ref** mode: builds a baseline
release and a target ref, runs unit tests + gen + sigproc validation on both,
and merges everything into a single comparison report PDF.

This wraps `ci-utilities/run-ci.sh --ref <baseline> --target-ref <target>`
followed by `ci-utilities/make-report.sh <run_dir>`.

There is also an **optional** extra pre-release check (see the "Optional"
section below): a multi-compiler-qualifier UPS packaging build (`e26` + `c14`
`prof`) via the `ssibuildshims` shim. It is **off by default** — only run it
when the user explicitly asks for the multi-qualifier / UPS build check (e.g.
"also do the shim build", "check it builds for e26 and c14"). Skipping it does
not affect the comparison report.

## Arguments

Parse from the user's request:
- **target** — the ref under test (branch/tag/`master`). Default: `master`.
- **baseline** — the reference release to compare against (a tag like `0.36.1`).

If the baseline is not given, ask the user which release to compare against
(or list recent tags with `git ls-remote --tags https://github.com/WireCell/wire-cell-toolkit`).
Do not guess a release tag.

## Preconditions

- Must run on **dunebuild03** (or a dunegpvm node) with CVMFS mounted.
- Everything except the final report merge runs **inside the SL7 apptainer**.
- The CI is heavy: two full wire-cell-toolkit builds + all unit tests + gen +
  sigproc. Expect **~1–2 hours**. Always run it in the background.

## Steps

### 1. Validate the baseline tag exists

```bash
git ls-remote --tags https://github.com/WireCell/wire-cell-toolkit | grep -E '<baseline>'
```

### 2. Launch the CI in the SL7 container (background)

Do **not** use `/exp/dune/app/users/yuhw/claude-utilities/in-gpvm-sl7.sh` on
dunebuild03: it binds `/pnfs`, which does not exist there, and apptainer
aborts. Launch apptainer directly with the bind list minus `/pnfs`. `run-ci.sh`
sources its own environment via `/exp/dune/app/users/yuhw/setup.sh`, so the
`path-prepend: command not found` warnings in the log are harmless.

Replace `<baseline>` and `<target>`:

```bash
cd /exp/dune/app/users/yuhw/wct-ci/ci-utilities
LOG=/exp/dune/app/users/yuhw/wct-pr-testing/run-ci-<target>-vs-<baseline>.log
IMG=/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest
APPTAINER=/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer
nohup "$APPTAINER" exec --ipc --pid \
  -B /cvmfs,/exp,/nashome,/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf \
  "$IMG" \
  /bin/bash -c "./run-ci.sh --ref <baseline> --target-ref <target>" \
  > "$LOG" 2>&1 &
echo "launched PID $! ; log: $LOG"
```

### 3. Wait for completion

The in-container run is done when the log prints `In-container steps done`
(it then echoes the exact `make-report.sh` command and the run directory).

Watch for that marker — **do not** poll with a `pgrep -f` pattern that contains
the `run-ci.sh ... --target-ref ...` string, because the watcher's own command
line will match the pattern and the loop will never exit. Either grep the log
for the marker, or track the launched PID directly. Example background watcher:

```bash
LOG=/exp/dune/app/users/yuhw/wct-pr-testing/run-ci-<target>-vs-<baseline>.log
until grep -q 'In-container steps done' "$LOG" 2>/dev/null; do sleep 60; done
echo "done"; tail -20 "$LOG"
```

The run directory is `…/wct-pr-testing/run-<timestamp>-target-<target>` —
read it from the `make-report.sh` line the run printed, or:
`ls -dt /exp/dune/app/users/yuhw/wct-pr-testing/run-*-target-<target> | head -1`

### 4. Merge the report (OUTSIDE the container)

```bash
/exp/dune/app/users/yuhw/wct-ci/ci-utilities/make-report.sh <run_dir>
```

This writes `<run_dir>/report-<target>-vs-<baseline>.pdf`.

### 5. Deliver and summarize

- Send the report PDF to the user (SendUserFile).
- Read `<run_dir>/01-pr-review.txt` and summarize the **Test overview** and the
  failure breakdown:
  - **Target-only failures** = candidate regressions in the target (inspect these).
  - **Failures common to reference and target** = pre-existing / environment-related.
  - **Reference-only failures** = baseline-only.
- Note the gen/sigproc validation plots are included in the PDF (signal frame +
  waveform comparison; sigproc frame + U/V/W-plane comparisons).

## Optional: multi-qualifier UPS build check (ssibuildshims)

**Off by default.** Run this only when the user explicitly asks to also verify
the release builds under multiple compiler qualifiers / as a UPS product. It is
independent of the comparison report and can be run on its own.

This builds wirecell as a UPS product for the `e26` (gcc) and `c14` (clang) prof
qualifiers using the shim repo at
`/exp/dune/app/users/yuhw/build-framework-wirecell-ssi-build`. That repo pins a
specific release in `version_info.sh` (e.g. `v0_36_1a` = the `0.36.1` tag plus
in-script compiler patches); to check a different release, the user must bump
`origpkgver` there first. The repo has its own `in-sl7.sh` wrapper (correct binds,
no `/pnfs`) — use it, not `claude-utilities/in-gpvm-sl7.sh`.

A reusable driver, `run-e26-c14-prof.sh`, already lives in that repo and builds
both qualifiers sequentially with the `PRODUCTS` fix baked in. Prefer it:

```bash
cd /exp/dune/app/users/yuhw/build-framework-wirecell-ssi-build
# Ensure the version dir exists (only needed if products/wirecell/<ver> is missing):
./in-sl7.sh ./bootstrap.sh /exp/dune/app/users/yuhw/products/   # > bootstrap.log
# Build e26 prof then c14 prof in the background:
nohup ./in-sl7.sh ./run-e26-c14-prof.sh \
  > build-e26-c14-prof-overall.log 2>&1 &
disown
```

Per-qualifier logs are `build_<cqual>_prof.log`; the driver log is
`build-e26-c14-prof-overall.log`. Watch for `ALL BUILDS DONE` in the overall log.

Success per qualifier = `is installed at .../wirecell/<ver>/Linux64bit*-<cqual>-prof`
in the log, a `build_completed-*-<cqual>-prof.stamp`, and a `bin/wire-cell` +
`lib/libWireCellApps.so` under that install dir.

**Known gotchas (all handled by the driver, but verify if invoking manually):**

1. **Bootstrap first.** `build_wirecell.sh` fails with "no write access to
   .../wirecell/<ver>" if the version dir doesn't exist. `bootstrap.sh` creates it
   (clones the pinned tag from GitHub and stages the source tar). It is idempotent.

2. **Pin `PRODUCTS`.** Run non-interactively, the shim's `ensure_ups` collapses
   `$PRODUCTS` to just the product dir, so dependencies (boost, hdf5, eigen,
   gcc/clang, gojsonnet, tbb, …) fail with "Found no match for product". Before
   each `build_wirecell.sh`, export the full search path (user products dir FIRST):
   ```bash
   export PRODUCTS=/exp/dune/app/users/yuhw/products/:/cvmfs/dune.opensciencegrid.org/products/dune:/cvmfs/larsoft.opensciencegrid.org/products:/cvmfs/larsoft.opensciencegrid.org/packages:/cvmfs/fermilab.opensciencegrid.org/products/common/db/
   ```
   Do **not** reuse the `PRODUCTS` variable as the product-dir argument — keep them
   separate (the driver uses `PRODUCT_DIR` for the arg).

3. **Disk quota.** `/exp/dune/app/users/yuhw` has a ~110 GiB CephFS quota (the
   filesystem itself has TBs free), so "Disk quota exceeded" mid-link is the quota.
   Check headroom: `getfattr -n ceph.dir.rbytes /exp/dune/app/users/yuhw` vs
   `ceph.quota.max_bytes`. Safe to reclaim: regenerable `build/` trees under
   `products/wirecell/<ver>/build/` of already-installed flavors (install dirs are
   separate; waf resumes incrementally if the build/ tree is kept). CephFS `rbytes`
   updates asynchronously — poll a few seconds after an `rm` before space registers.

Manual single-qualifier invocation (if not using the driver):
```bash
cd /exp/dune/app/users/yuhw/build-framework-wirecell-ssi-build
./in-sl7.sh bash -c 'export PRODUCTS=/exp/dune/app/users/yuhw/products/:/cvmfs/dune.opensciencegrid.org/products/dune:/cvmfs/larsoft.opensciencegrid.org/products:/cvmfs/larsoft.opensciencegrid.org/packages:/cvmfs/fermilab.opensciencegrid.org/products/common/db/; ./build_wirecell.sh /exp/dune/app/users/yuhw/products/ e26 prof'
```

## Notes

- `run-ci.sh` writes `ci-meta.env` into the run dir, so `make-report.sh` needs
  only the run directory (no PR number).
- To skip rebuilding when reruning validation only, add `--skip-build`
  (and optionally `--skip-tests`) to the `run-ci.sh` invocation.
- See `ci-utilities/README.md` for full flag documentation.
