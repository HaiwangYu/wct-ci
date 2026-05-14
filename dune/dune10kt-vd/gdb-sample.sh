rm -f lar.pid detsim.time

/usr/bin/time -v -o detsim.time bash -c '
  lar -n -1 -c detsim-dom+local.fcl -s input.root -o detsim.root \
    > detsim.n0.out 2> detsim.n0.err &
  echo $! > lar.pid
  wait $!
' &
timepid=$!

while [ ! -s lar.pid ] && kill -0 "$timepid" 2>/dev/null; do
  sleep 0.1
done

larpid=$(cat lar.pid)

echo "time pid = $timepid"
echo "lar pid = $larpid"

i=0
while kill -0 "$larpid" 2>/dev/null; do
  i=$((i+1))
  echo "===== sample $i $(date) ====="
  gdb -batch -p "$larpid" \
    -ex "set pagination off" \
    -ex "thread apply all bt 12"
  sleep 5
done > full.gdb-samples.txt 2>&1

wait "$timepid"
