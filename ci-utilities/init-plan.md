# implement a local test system to validate wire-cell-toolkit PRs
- goal: run the test system to get a pdf validation report
- main repo to test: https://github.com/WireCell/wire-cell-toolkit
- helper repo for some more tests: https://github.com/HaiwangYu/wct-ci
- input: reference (a tag or master for current master), GitHub PR number
- output:
  - summary of running `./wcb --tests --alltests` for wire-cell-toolkit
  - plots for running wct-ci/gen adn wct-ci/sigproc, use the README.md in those folders to form how to run and make figures.

- test setup on a dunebuild03 or dunegpvm machine
```bash
sl7 () 
{ 
    /cvmfs/oasis.opensciencegrid.org/mis/apptainer/current/bin/apptainer shell --shell=/bin/bash -B /cvmfs,/exp,/nashome,${1},/opt,/run/user,/etc/hostname,/etc/hosts,/etc/krb5.conf --ipc --pid /cvmfs/singularity.opensciencegrid.org/fermilab/fnal-dev-sl7:latest;
    source /nashome/y/yuhw/.bash_profile;
    export PS1=(app)$PS1
}
```
source /exp/dune/app/users/yuhw/setup.sh
- instruction to build wire-cell-toolkit
```bash
./gpvm/configure-ssi-gcc.sh
./wcb -p --notests build install
```
- in the plan, put all utility scripts in the wct-ci/ci-utilities folder. But just writ the plan for now. Do not implement yet
- ask me if anything is not clear.