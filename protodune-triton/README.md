
```bash

```

```bash
lar -n1 -c gen_protodunevd_cosmics.fcl -o gen.root
lar -n1 -c protodunevd_refactored_g4_stage1.fcl gen.root -o g4a.root
lar -n1 -c protodunevd_refactored_g4_stage2_pureAr.fcl g4a.root -o g4b.root
lar -n1 -c protodunevd_refactored_detsim_pureAr.fcl g4b.root -o detsim.root
lar -n1 -c protodunevd_reco.fcl detsim.root -o reco.root
```


```bash
lar -n1 -c detsim.fcl g4b.root -o detsim.root
lar -n1 -c reco.fcl detsim.root -o reco.root
```


`v10_06_00d01` stuck at g4a -> g4b for at least 30min

```bash
%MSG
%MSG-i PhotonLibrary:  PDFastSimPVS:PDFastSim@BeginModule  23-Sep-2025 12:04:51 CDT run: 1 subRun: 0 event: 1
Reading photon library from input file: /cvmfs/dune.osgstorage.org/pnfs/fnal.gov/usr/dune/persistent/stash/PhotonPropagation/LibraryData/libext_protodunevd_v4_Ar_Baseline_v09_69_00d00_5e7_25x25x25_landau_20231216.root
%MSG
%MSG-i PhotonLibrary:  PDFastSimPVS:PDFastSim@BeginModule  23-Sep-2025 12:04:51 CDT run: 1 subRun: 0 event: 1
Photon lookup table size : 15625 voxels,  40 channels (no voxel geometry included)
%MSG
```