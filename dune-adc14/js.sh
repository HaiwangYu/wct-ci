cfg1=/exp/dune/app/users/yuhw/larsoft/v10_04_03d01/localProducts_larsoft_v10_04_03_e26_prof/dunereco/v10_04_04d00/wire-cell-cfg
cfg1=/cvmfs/dune.opensciencegrid.org/products/dune/dunereco/v10_04_03d01/wire-cell-cfg
cfg2=/cvmfs/larsoft.opensciencegrid.org/products/wirecell/v0_29_5/Linux64bit+3.10-2.17-e26-prof/share/wirecell

name=$2
name=${name%.jsonnet}

if [[ $1 == "json" || $1 == "all" ]]; then
jsonnet \
--ext-str engine="TbbFlow" \
--ext-str files_wires="dunevd10kt_3view_v2_refactored_1x8x14ref.json.bz2" \
--ext-str files_fields="dunevd-resp-isoc3views-18d92.json.bz2" \
--ext-str files_noise="dunevd10kt-1x6x6-3view-noise-spectra-v1.json.bz2" \
--ext-str geo_planeid_labels="dunevd_3view" \
--ext-str process_crm="full" \
--ext-str input="depos.tar.bz2" \
--ext-str output="test.tar.bz2" \
--ext-code nticks=6000 \
--ext-code DL=10 \
--ext-code DT=10 \
--ext-code lifetime=10 \
--ext-code driftSpeed=1.60563 \
--ext-code G4RefTime=0 \
--ext-code response_plane=18.92 \
--ext-code ncrm=112 \
--ext-code use_dnnroi=false \
--ext-code use_hydra=false \
--ext-code wire_col_nsigma=3 \
-J $cfg1 \
-J $cfg2 \
${name}.jsonnet \
-o ${name}.json
fi

if [[ $1 == "pdf" || $1 == "all" ]]; then
    #wirecell-pgraph dotify --jpath -1 --no-services --no-params ${name}.json ${name}.pdf
    wirecell-pgraph dotify --jpath -1 --no-params ${name}.json ${name}.pdf
fi
