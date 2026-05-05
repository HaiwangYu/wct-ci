#!/bin/bash

J_ARGS=""
IFS=':' read -ra cfg_dirs <<< "$WIRECELL_PATH"
for (( idx=${#cfg_dirs[@]}-1; idx>=0; idx-- )); do
    J_ARGS="$J_ARGS -J ${cfg_dirs[$idx]}"
done

name=${2:-pgrapher/experiment/dune-vd/wcls-sim-drift-simchannel-nf-sp.jsonnet}
name=${name%.jsonnet}
input_jsonnet="${name}.jsonnet"
output_name=$(basename "$name")

if [[ ! -f "$input_jsonnet" ]]; then
    if [[ -n "$WIRECELL_PATH" ]]; then
        IFS=':' read -ra cfg_dirs <<< "$WIRECELL_PATH"
        for cfg_dir in "${cfg_dirs[@]}"; do
            if [[ -f "$cfg_dir/$input_jsonnet" ]]; then
                input_jsonnet="$cfg_dir/$input_jsonnet"
                break
            fi
        done
    elif [[ -f "$cfg1/$input_jsonnet" ]]; then
        input_jsonnet="$cfg1/$input_jsonnet"
    fi
fi

if [[ $1 == "json" || $1 == "all" ]]; then
jsonnet \
--ext-str engine="TbbFlow" \
--ext-str files_wires="dunevd10kt_3view_30deg_v7_refactored_1x8x14.json.bz2" \
--ext-str files_fields="dunevd-resp-isoc3views-18d92.json.bz2" \
--ext-str files_noise="dunevd10kt-1x6x6-3view30deg-noise-spectra-v1.json.bz2" \
--ext-str geo_planeid_labels="default" \
--ext-str process_mode="single-sim-sp" \
--ext-code nticks=8500 \
--ext-code DL=4e-9 \
--ext-code DT=8.8e-9 \
--ext-code lifetime=10400 \
--ext-code driftSpeed=1.60563 \
--ext-code G4RefTime=0 \
--ext-code response_plane=18.92 \
--ext-code Nbit=14 \
--ext-code elecGain=14 \
--ext-code ncrm=320 \
--ext-code process_tpc_index=0 \
--ext-code use_dnnroi=false \
--ext-code use_hydra=true \
--ext-code save_rawdigits=false \
--ext-code adc_resolution=12 \
$J_ARGS \
"$input_jsonnet" \
-o "${output_name}.json"
fi

if [[ $1 == "pdf" || $1 == "all" ]]; then
    #wirecell-pgraph dotify --jpath -1 --no-services --no-params ${output_name}.json ${output_name}.pdf
    wirecell-pgraph dotify --jpath -1 --no-params "${output_name}.json" "${output_name}.pdf"
fi
