source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh

# setup dunesw v10_02_02d00 -q e26:prof
# source /exp/dune/app/users/yuhw/larsoft/v10_02_02d00/localProducts_larsoft_v10_02_02_e26_prof/setup

setup dunesw v10_04_03d01 -q e26:prof
source /exp/dune/app/users/yuhw/larsoft/v10_04_03d01/localProducts_larsoft_v10_04_03_e26_prof/setup

mrbsetenv
mrbslp

path-prepend /exp/dune/app/users/yuhw/opt/lib64 LD_LIBRARY_PATH
path-prepend /exp/dune/app/users/yuhw/wct/cfg WIRECELL_PATH
