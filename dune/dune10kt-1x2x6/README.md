```bash
lar -n 1 -c prod_eminus_500MeV_uniform_dune10kt_1x2x6.fcl -o gen.root
lar -n 1 -c standard_g4_dune10kt_1x2x6.fcl -s gen.root -o g4.root
lar -n 1 -c standard_detsim_dune10kt_1x2x6.fcl -s g4.root -o detsim.root
```


```bash
find-in-env () 
{ 
    fhicl_file=$1;
    for path in `echo $2  | sed -e 's/:/\n/g'`;
    do
        echo $path
        find $path -maxdepth 1 -name "$fhicl_file" 2> /dev/null;
    done
}
find-in-env pgrapher/experiment/dune10kt-1x2x6/wcls-sim-drift-simchannel-nf-sp.jsonnet $WIRECELL_PATH


find-jsonnet () {
    local target=$1
    local paths=${2:-$WIRECELL_PATH}
    local IFS=:
    local found=0
    for path in $paths; do
        [ -e "$path/$target" ] && { echo "$path/$target"; found=1; break;}
    done
    if [ $found -eq 0 ]; then
        for path in $paths; do
            find "$path" -name "$(basename "$target")" 2>/dev/null
        done
    fi
}
find-jsonnet pgrapher/experiment/dune10kt-1x2x6/wcls-sim-drift-simchannel-nf-sp.jsonnet
```