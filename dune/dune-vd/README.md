
this fcl was copied from https://github.com/alessandrothea/dunetrg-cards/blob/main/fcl/vd/gen_vd_1x8x14_muminus_center.fcl

```bash
lar -n 1 -c gen_vd_1x8x14_muminus_center.fcl -o gen.root
lar -n 1 -c standard_g4_dunevd10kt_1x8x14_3view_30deg.fcl -s gen.root -o g4.root
lar -n 1 -c standard_detsim_dunevd10kt_1x8x14_3view_30deg.fcl -s g4.root -o sp.root
lar -n 1 -c detsim.fcl -s g4.root -o sp.root
```