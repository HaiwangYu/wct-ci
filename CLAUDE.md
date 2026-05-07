# wire-cell-toolkit — build environment

This project must be built inside the Fermilab SL7 apptainer with the
icarus/wirecell environment from `/exp/sbnd/app/users/yuhw/wcdev-icarus/setup.sh`.
**Do not run `./wcb`, `cmake`, `pytest`, or compiled test binaries directly on
the host** — they will pick up the wrong toolchain (host system gcc/spdlog
instead of `e26 prof` from cvmfs) and fail in confusing ways.

## How to build / test

Prefix every build or test command with `tools/in-sl7.sh`. It is a
non-interactive mirror of the user's interactive `sl7` shell function +
`setup.sh`.

- Full build: `tools/in-sl7.sh ./wcb -p --notests build install`
- Single subpackage: `tools/in-sl7.sh ./wcb --notests --target=WireCellApps`
- Run a unit test binary: `tools/in-sl7.sh build/util/test_<foo>`
- Inspect environment: `tools/in-sl7.sh bash -c 'which wcb; echo $CMAKE_PREFIX_PATH'`

## Environment source of truth

- Image: `/cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest`
- Setup script: `/exp/sbnd/app/users/yuhw/wcdev-icarus/setup.sh`
  (sets up `icaruscode v10_20_03 -q e26:prof` plus user paths)
- Wrapper: `tools/in-sl7.sh`
