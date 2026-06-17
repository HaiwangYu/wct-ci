# wct-ci utilities

Scripts for running a local CI validation of [wire-cell-toolkit](https://github.com/WireCell/wire-cell-toolkit) pull requests.

## Requirements

- Run on a **dunebuild03** or **dunegpvm** machine inside the SL7 Apptainer container
- CVMFS must be mounted
- `/exp/dune/app/users/yuhw/setup.sh` must be present

## Quick start

**Step 1 — inside the SL7 container** (build, test, simulate, plot):
```bash
# Enter the container
/cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer shell \
  --shell=/bin/bash \
  -B /cvmfs,/exp,/nashome,/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf \
  --ipc --pid \
  /cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest

cd /exp/dune/app/users/yuhw/wct-ci/ci-utilities
./run-ci.sh --ref master --pr <PR_number>
```

At the end, `run-ci.sh` prints the exact command for step 2.

**Step 2 — outside the container** (merge PDFs into report):
```bash
cd /exp/dune/app/users/yuhw/wct-ci/ci-utilities
./make-report.sh <run_dir>
```
`run-ci.sh` writes a `ci-meta.env` into the run directory, so `make-report.sh`
only needs the run directory (the trailing PR number is optional, kept for
backward compatibility with old runs that have no `ci-meta.env`).

The final report is written into the run directory as `report-<label>.pdf`
(`report-pr<N>.pdf` for PR runs, `report-<target>-vs-<ref>.pdf` for
`--target-ref` runs).

## Options

| Flag | Description |
|------|-------------|
| `--ref <tag\|master>` | Reference to build and compare against (e.g. `master`, `0.33.0`) |
| `--pr <N>` | GitHub PR number to test |
| `--target-ref <ref>` | Test an arbitrary ref (tag/master/branch) against `--ref` instead of a PR. Mutually exclusive with `--pr`. |
| `--merge-pr` | Test the PR as `<ref>` plus the PR head merged in, instead of testing the PR head directly (PR mode only) |
| `--skip-build` | Skip clone, configure, and build entirely; use existing installs in the work dir |
| `--skip-tests` | Skip `./wcb --tests --alltests` for ref and target; jump straight to gen/sigproc validation |

The side under test is called the **target**. It is either a GitHub PR (`--pr`)
or an arbitrary ref (`--target-ref`).

Example — test PR 451 after merging it into current `master`:
```bash
./run-ci.sh --ref master --pr 451 --merge-pr
```

Example — compare current `master` against the `0.36.1` release
(`--ref` is the baseline, `--target-ref` is the side under test):
```bash
./run-ci.sh --ref 0.36.1 --target-ref master
```

Example — re-run gen/sigproc only, skipping build and unit tests:
```bash
./run-ci.sh --ref master --pr 467 --skip-build --skip-tests
```

## What it does

**Inside container** (`run-ci.sh`):

| Step | Script | Description |
|------|--------|-------------|
| 1 | `build-wct.sh` | Clones wct, checks out reference tag/master, builds and installs |
| 2 | `build-wct.sh` | Builds the PR branch, or with `--merge-pr`, checks out the reference and merges the PR head before building |
| 3 | `run-wct-tests.sh` | Runs `./wcb --tests --alltests` on the reference and PR builds, saving full logs and failure-only summaries |
| 4 | `run-gen.sh` | Runs signal simulation (`gen/`) for ref and PR, produces individual plot PDFs |
| 5 | `run-sigproc.sh` | Runs signal processing (`sigproc/`) for ref and PR, produces individual plot PDFs |

For `--skip-build` reruns, the validation scripts use the local build-tree
executable (`<src>/build/apps/wire-cell`) and prepend all `<src>/build/*`
library directories. They do not silently fall back to the CVMFS `wire-cell`
executable if the install prefix is absent.

**Outside container** (`make-report.sh`):

| Step | Script | Description |
|------|--------|-------------|
| 6 | `make-report.sh` | Merges all individual PDFs into a single report using `pdfunite` |

## Work directory layout

```
/exp/dune/app/users/yuhw/wct-pr-testing/
├── ref-src/            # reference wct source
├── ref-install/        # reference install prefix
├── pr-<N>-src/         # PR wct source
├── pr-<N>-install/     # PR install prefix
└── run-<timestamp>-pr<N>/
    ├── build-ref.log
    ├── build-pr.log
    ├── ref-wct-tests.log
    ├── ref-wct-tests-failures.txt
    ├── pr-wct-tests.log
    ├── pr-wct-tests-failures.txt
    ├── 01-pr-review.txt
    ├── ref-gen/
    ├── pr-gen/
    ├── ref-sigproc/
    ├── pr-sigproc/
    └── report-pr<N>.pdf
```
