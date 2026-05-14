```bash
fhicl-dump standard_detsim_dunevd10kt.fcl >& detsim-dom+local.fcl
lar -n 1 -c standard_detsim_dunevd10kt.fcl -s input.root -o detsim.root
lar -n 1 -c detsim-dom+local.fcl -s input.root -o detsim.root
```

## optimization
```bash
/usr/bin/time -v bash -c '
  lar -n 3 -c detsim-dom+local.fcl -s input.root -o detsim.root \
  > >(awk "{ print strftime(\"[%F %T]\"), \$0; fflush(); }" > detsim.timestamped.out) \
  2> >(awk "{ print strftime(\"[%F %T]\"), \$0; fflush(); }" > detsim.timestamped.err)
'
```
```bash
pid=$(pgrep -n lar)

for i in $(seq 1 20); do
  echo "===== sample $i $(date) ====="
  gdb -batch -p "$pid" \
    -ex "set pagination off" \
    -ex "thread apply all bt 8"
  sleep 3
done > startup.gdb-samples.txt 2>&1
```

```bash
# single-sp, APA141
python ../../visualization-utilities/plot_detsim.py \
  --input detsim.root \
  --simch-tag simpleSC141 \
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