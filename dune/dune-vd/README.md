
this fcl was copied from https://github.com/alessandrothea/dunetrg-cards/blob/main/fcl/vd/gen_vd_1x8x14_muminus_center.fcl

gen, g4
```bash
lar -n 1 -c gen_vd_1x8x14_muminus_center.fcl -o gen.root
lar -n 1 -c standard_g4_dunevd10kt_1x8x14_3view_30deg.fcl -s gen.root -o g4.root
```

detsim
```bash
lar -n 1 -c standard_detsim_dunevd10kt_1x8x14_3view_30deg.fcl -s g4.root -o detsim.root
fhicl-dump standard_detsim_dunevd10kt_1x8x14_3view_30deg.fcl >& detsim.fcl
lar -n 1 -c detsim.fcl -s g4.root -o detsim.root
```

864 channels per APA (CRM for non-bridged)
APA28: 23328 24192

24250 24800

visualization
```bash
# full
python ../../visualization-utilities/plot_detsim.py \
  --input detsim.root \
  --wire-tag gauss \
  --channel-min 24300 --channel-max 24400 \
  --tick-min 4500 --tick-max 5500 \
  --vmax-percentile 90.0 \
  --cmap YlOrRd \
  --interactive

# single-sp
python ../../visualization-utilities/plot_detsim.py \
  --input detsim.root \
  --wire-tag gauss28 \
  --channel-min 24300 --channel-max 24400 \
  --tick-min 4500 --tick-max 5500 \
  --vmax-percentile 90.0 \
  --cmap YlOrRd \
  --interactive
```