
  --channel-min 24300 --channel-max 24400 \
  --tick-min 4500 --tick-max 5500 \

```bash
python ../../visualization-utilities/plot_detsim.py \
  --input detsim.root \
  --simch-branch "sim::SimChannels_tpcrawdecoder_simpleSC_Detsim.obj" \
  --wire-branch "recob::Wires_wclsdatavd_gauss_pdvdsimstage0.obj" \
  --wire-tag gauss \
  --channel-min 6000 --channel-max 12000 \
  --tick-min 3500 --tick-max 4500 \
  --vmax-percentile 90.0 \
  --cmap YlOrRd \
  --interactive
```


     Size in bytes   Fraction Data Product Name
          64758223      0.853 raw::RawDigits_tpcrawdecoder_daq_Detsim.
           3997486      0.053 raw::OpDetWaveforms_opdigi__Detsim.
           1172114      0.015 sim::OpDetBacktrackerRecords_PDFastSimAr__G4Stage2.
           1052866      0.014 sim::SimEnergyDeposits_IonAndScint_priorSCE_G4Stage2.
           1052833      0.014 sim::SimEnergyDeposits_IonAndScint__G4Stage2.
           1017562      0.013 sim::SimEnergyDeposits_largeant_LArG4DetectorServicevolTPCActive_G4Stage1.
            585413      0.008 sim::SimChannels_tpcrawdecoder_simpleSC_Detsim.
            304746      0.004 recob::Wires_wclsdatavd_gauss_pdvdsimstage0.
            301336      0.004 recob::Wires_wclsdatavd_wiener_pdvdsimstage0.
            285580      0.004 recob::SpacePoints_cluster3d__pdvdsimstage0.
            270678      0.004 recob::Hits_hitpdune__pdvdsimstage0.
            248307      0.003 recob::Hits_gaushit__pdvdsimstage0.
            179194      0.002 sim::SimEnergyDepositLites_sedlite__G4Stage2.
            111400      0.001 sim::SimPhotonsLites_PDFastSimAr__G4Stage2.
            110375      0.001 recob::Hitrecob::SpacePointvoidart::Assns_cluster3d__pdvdsimstage0.
             72299      0.001 sim::OpDetDivRecs_opdigi__Detsim.
             59652      0.001 recob::Hits_cluster3d__pdvdsimstage0.
             48467      0.001 simb::MCParticles_simplemerge__G4Stage1.
             31904      0.000 simb::MCParticles_largeant_droppedMCParticles_G4Stage1.
             24505      0.000 recob::Hitrecob::Wirevoidart::Assns_hitpdune__pdvdsimstage0.
             21141      0.000 recob::Hitrecob::Wirevoidart::Assns_gaushit__pdvdsimstage0.
             17919      0.000 simb::MCParticles_largeant__G4Stage1.
             17157      0.000 recob::SpacePoints_reco3d_pre_pdvdsimstage0.
             14576      0.000 recob::Clusters_cluster3d__pdvdsimstage0.
             14259      0.000 recob::SpacePoints_reco3d_noreg_pdvdsimstage0.
             13004      0.000 recob::Hitrecob::SpacePointvoidart::Assns_reco3d__pdvdsimstage0.
             12671      0.000 recob::SpacePoints_reco3d__pdvdsimstage0.
             12556      0.000 recob::Hitrecob::SpacePointvoidart::Assns_hitpdune__pdvdsimstage0.
             10058      0.000 recob::PCAxiss_cluster3d__pdvdsimstage0.
              8674      0.000 recob::SpacePoints_cluster3d_Path_pdvdsimstage0.
              7770      0.000 sim::MCTracks_mcreco__G4Stage2.
              6771      0.000 recob::PointCharges_reco3d_noreg_pdvdsimstage0.
              5899      0.000 recob::PointCharges_reco3d__pdvdsimstage0.
              5548      0.000 recob::Edges_cluster3d_Path_pdvdsimstage0.
              4301      0.000 recob::Hitrecob::SpacePointvoidart::Assns_cluster3d_Path_pdvdsimstage0.
              4213      0.000 recob::Edgerecob::SpacePointvoidart::Assns_cluster3d_Path_pdvdsimstage0.
              4210      0.000 recob::SpacePoints_cluster3d_Vertex_pdvdsimstage0.
              4159      0.000 sim::SimEnergyDeposits_largeant_LArG4DetectorServicevolCryostat_G4Stage1.
              3921      0.000 recob::Clusterrecob::Hitvoidart::Assns_cluster3d__pdvdsimstage0.
              2742      0.000 recob::PointCharges_reco3d_pre_pdvdsimstage0.
              2724      0.000 recob::Edgerecob::PFParticlevoidart::Assns_cluster3d_Path_pdvdsimstage0.
              2570      0.000 recob::PFParticlerecob::SpacePointvoidart::Assns_cluster3d__pdvdsimstage0.
              2431      0.000 recob::PFParticlerecob::SpacePointvoidart::Assns_cluster3d_Path_pdvdsimstage0.
              2223      0.000 recob::Clusterrecob::PFParticlevoidart::Assns_cluster3d__pdvdsimstage0.
              2036      0.000 recob::PCAxisrecob::PFParticlevoidart::Assns_cluster3d__pdvdsimstage0.
              2020      0.000 recob::Edges_cluster3d_Vertex_pdvdsimstage0.
              1945      0.000 sim::MCShowers_mcreco__G4Stage2.
              1755      0.000 art::RNGsnapshots_rns__G4Stage2.
              1673      0.000 art::RNGsnapshots_rns__G4Stage1.
              1668      0.000 art::RNGsnapshots_rns__Detsim.
              1666      0.000 sim::ParticleAncestryMap_largeant__G4Stage1.
              1535      0.000 simb::MCParticlesimb::MCTruthsim::GeneratedParticleInfoart::Assns_largeant__G4Stage1.
              1422      0.000 recob::Edgerecob::SpacePointvoidart::Assns_cluster3d__pdvdsimstage0.
              1393      0.000 sim::AuxDetHits_largeant_LArG4DetectorServicevolAuxDetSensitiveCRTDPPaddleBottom_G4Stage1.
              1392      0.000 recob::PFParticles_cluster3d__pdvdsimstage0.
              1386      0.000 simb::MCTruths_generator__SinglesGen.
              1378      0.000 sim::AuxDetHits_largeant_LArG4DetectorServicevolAuxDetSensitiveCRTDPPaddleTop_G4Stage1.
              1368      0.000 recob::Edgerecob::PFParticlevoidart::Assns_cluster3d__pdvdsimstage0.
              1319      0.000 sim::SimEnergyDeposits_largeant_LArG4DetectorServicevolBeamPlIINi_G4Stage1.
              1306      0.000 recob::PFParticlerecob::Seedvoidart::Assns_cluster3d__pdvdsimstage0.
              1289      0.000 raw::RawDigitrecob::Hitvoidart::Assns_cluster3d__pdvdsimstage0.
              1270      0.000 recob::Hitrecob::Seedvoidart::Assns_cluster3d__pdvdsimstage0.
              1268      0.000 recob::Hitrecob::Wirevoidart::Assns_cluster3d__pdvdsimstage0.
              1264      0.000 CRTVD::Triggersimb::MCParticlevoidart::Assns_crt__Detsim.
              1229      0.000 recob::Edges_cluster3d__pdvdsimstage0.
              1203      0.000 art::TriggerResults_TriggerResults__pdvdsimstage0.
              1193      0.000 recob::SpacePoints_cluster3d_Extreme_pdvdsimstage0.
              1191      0.000 art::TriggerResults_TriggerResults__SinglesGen.
              1176      0.000 art::TriggerResults_TriggerResults__G4Stage2.
              1175      0.000 art::TriggerResults_TriggerResults__G4Stage1.
              1168      0.000 art::TriggerResults_TriggerResults__Detsim.
              1124      0.000 recob::Seeds_cluster3d__pdvdsimstage0.
              1069      0.000 CRTVD::Triggers_crt__Detsim.
               460      0.000 EventAuxiliary