```bash
path-prepend /exp/dune/data/users/hnam/wire-cell-hnam/larwc/wire-cell-cfg/ WIRECELL_PATH
lar -n 1 -c my_pdhd_wirecell_sim_deposplat.fcl -s g4_1GeV_theta0.root --no-output | tee log
```