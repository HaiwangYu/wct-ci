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
./make-report.sh /exp/dune/app/users/yuhw/wct-pr-testing/run-<timestamp>-pr<N> <PR_number>
```

The final report is written to:
```
/exp/dune/app/users/yuhw/wct-pr-testing/run-<timestamp>-pr<N>/report-pr<N>.pdf
```

## Options

| Flag | Description |
|------|-------------|
| `--ref <tag\|master>` | Reference to build and compare against (e.g. `master`, `0.33.0`) |
| `--pr <N>` | GitHub PR number to test |
| `--skip-build` | Skip clone, configure, and build entirely; use existing installs in the work dir |
| `--skip-tests` | Skip `./wcb --tests --alltests`; jump straight to gen/sigproc validation |

Example — re-run gen/sigproc only, skipping build and unit tests:
```bash
./run-ci.sh --ref master --pr 467 --skip-build --skip-tests
```

## What it does

**Inside container** (`run-ci.sh`):

| Step | Script | Description |
|------|--------|-------------|
| 1 | `build-wct.sh` | Clones wct, checks out reference tag/master, builds and installs |
| 2 | `build-wct.sh` | Same for the PR branch |
| 3 | `run-wct-tests.sh` | Runs `./wcb --tests --alltests` on the PR build |
| 4 | `run-gen.sh` | Runs signal simulation (`gen/`) for ref and PR, produces individual plot PDFs |
| 5 | `run-sigproc.sh` | Runs signal processing (`sigproc/`) for ref and PR, produces individual plot PDFs |

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
    ├── wct-tests.log
    ├── ref-gen/
    ├── pr-gen/
    ├── ref-sigproc/
    ├── pr-sigproc/
    └── report-pr<N>.pdf
```
