# Dom's setup script for dune10kt-vd
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunesw v10_14_00d00 -q e26:prof
source /exp/dune/app/users/dbrailsf/10kt/vd/localProducts_larsoft_v10_14_00_e26_prof/setup
mrbslp

# local dunereco
path-prepend /exp/dune/app/users/$USER/wire-cell-cfg WIRECELL_PATH
path-prepend /exp/dune/app/users/yuhw/dunereco/dunereco/DUNEWireCell/dune10kt-vd WIRECELL_PATH
path-prepend /exp/dune/app/users/$USER/dunereco/dunereco/DUNEWireCell/ FHICL_FILE_PATH

source /nashome/y/$USER/.bash_profile
export PS1=(dom)$PS1

source /exp/dune/app/users/$USER/wire-cell-python/venv/bin/activate