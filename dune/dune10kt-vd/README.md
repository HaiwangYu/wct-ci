```bash
fhicl-dump standard_detsim_dunevd10kt.fcl >& detsim-dom+local.fcl
lar -n 1 -c standard_detsim_dunevd10kt.fcl -s input.root -o detsim.root
lar -n 1 -c detsim-dom+local.fcl -s input.root -o detsim.root
```

```bash
# single-sp, APA141
python ../../visualization-utilities/plot_detsim.py \
  --input detsim.root \
  --wire-tag gauss141 \
  --channel-min 212500 --channel-max 213000 \
  --tick-min 0 --tick-max 1500 \
  --vmax-percentile 90.0 \
  --cmap YlOrRd \
  --interactive

# full
python ../../visualization-utilities/plot_detsim.py \
  --input detsim.root \
  --wire-tag gauss \
  --channel-min 212500 --channel-max 213000 \
  --tick-min 0 --tick-max 1500 \
  --vmax-percentile 90.0 \
  --cmap YlOrRd \
  --interactive
```

Channels per APA: 491520/320 = 1536
APA 141: 215040 - 216576

```bash
./js.sh all
```