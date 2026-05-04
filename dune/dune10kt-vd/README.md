```bash
fhicl-dump standard_detsim_dunevd10kt.fcl >& detsim-dom+local.fcl
lar -n 1 -c detsim-dom+local.fcl -s input.root -o detsim.root

python visualization-utilities/plot_detsim.py \
  --input dune/dune10kt-vd/detsim.root \
  --wire-tag gauss \
  --channel-min 215040 --channel-max 216576 \
  --tick-min 1000 --tick-max 2000 \
  --vmax-percentile 90.0 \
  --cmap YlOrRd \
  --interactive
```

Channels per APA: 491520/320 = 1536
APA 141: 215040 - 216576