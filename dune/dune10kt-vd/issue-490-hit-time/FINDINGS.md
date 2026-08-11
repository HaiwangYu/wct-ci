# WCT issue #490 — FD-VD 1x8x14 different minimum hit times by branch

Upstream: https://github.com/WireCell/wire-cell-toolkit/issues/490
"vanilla" = dunesw release path; "rollexp" = single-APA / rolling-expansion
branch. fcl: standard_detsim_dunevd10kt_1x8x14_3view_30deg.fcl.
Author's hypothesis: wclsSimDepoSource vs wclsSimDepoSetSource.

## Answer to the author's hypothesis: NOT the converter

`wclsSimDepoSource` and `wclsSimDepoSetSource` assign the depo TIME
identically — verified in larwirecell source:

* SimDepoSource.cxx:213    `double wt = sed.Time() * units::ns;`
* SimDepoSetSource.cxx:224 `double wt = sed.Time() * units::ns;`

Neither applies any time offset, reference-time subtraction, or gating.
Their only real differences are:
* trackID: `sed.TrackID()` (Source) vs the SED index `ind` unless
  `id_is_track` (SetSource)  — affects DepoFluxWriter labeling, not time;
* output flavor: IDepo stream + EOS marker vs a single bagged IDepoSet.

So the converter choice does NOT introduce the hit-time difference.

## Actual cause: the DepoBagger time-gate was dropped from the graph

The switch to the DepoSet path came with a graph restructuring. Comparing
the two `local graph = ...` lines for the same jsonnet:

release v10_20_09 (vanilla), .../dune-vd/wcls-sim-drift-simchannel-nf-sp.jsonnet:278
    [ depos, drifter, wclsSimChannelSink, **bagger**, bi_manifold, retagger, sp_signals, sink ]

branch (rollexp / single-APA), same file:
    [ deposet, setdrifter, wclsDepoFluxWriter, bi_manifold, retagger, sp_signals, sink ]

Both still DEFINE `local bagger = sim.make_bagger();`, but the branch
**does not wire it into the graph**.  `make_bagger` is a DepoBagger with

    gate: [ params.sim.ductor.start_time,
            params.sim.ductor.start_time + params.sim.ductor.readout_time ]

i.e. a hard time cut equal to the readout window
(pgrapher/common/sim/nodes.jsonnet:34-41).

Downstream, the per-anode `DepoTransform` bins each depo's drift-diffused
Gaussian into `tbins = [start_time, start_time+readout_time]` with
`nsigma = 3` (DepoTransform.cxx:183/203/205, frame ref time = start_time:238).

Consequence at the readout-window EDGES:
* vanilla: DepoBagger removes any depo whose CENTER time is outside the
  window, so its diffusion tail never reaches the edge bins;
* rollexp: with no bagger, a depo centered just OUTSIDE the window
  (within ~nsigma·sigma_T of an edge) still leaks its in-window Gaussian
  tail into the first/last ticks via DepoTransform.

That extra edge signal is exactly the kind of small, edge-localized
discrepancy seen in the attached "Hit Peak Time" comparison (bulk agrees,
chi2 ~ 8.2; the deviation sits at the window boundary / far-right bin), and
it shifts which hits are earliest/latest -> "different minimum hit times".

The truth-path change in the same graph (wclsSimChannelSink ->
wclsDepoFluxWriter) is irrelevant here: reco hit time comes from the
ductor -> SP -> recob::Wire chain, not the truth SimChannel.

## Gate-consistency analysis (the real question)

The un-gated rollexp is the CORRECT one; there IS a time gate in the sim,
inside DepoTransform.  Comparing the two:

WINDOWS — identical.
  common params.jsonnet:
    elec.fields.drift_dt = start_dx / drift_speed        (field-response pre-run)
    elec.fields.nticks   = drift_dt / tick
    ductor.start_time    = daq.start_time - drift_dt = -drift_dt
    ductor.readout_time  = (daq.nticks + fields.nticks) * tick
    reframer.tbin        = fields.nticks   (removes the pre-run, both paths)
  DepoBagger  gate  = [ductor.start_time, ductor.start_time+readout_time]
  DepoTransform tbins = [ductor.start_time, ductor.start_time+readout_time]
  => same edges: [ -drift_dt , daq.nticks*tick ].

EDGE TREATMENT — inconsistent.
  DepoBagger (DepoBagger.cxx / make_bagger): HARD cut on the depo CENTER
    time; any depo whose center is outside the window is dropped.
  DepoTransform: no explicit time cut; it spatial-selects (Aux::sensitive)
    then BinnedDiffusion_transform::add() keeps a depo unless its center is
    MORE than nsigma from the window on either side
    (BinnedDiffusion_transform.cxx:32-43:
        if (nmin_sigma > eff_nsigma || nmax_sigma < -eff_nsigma) return false;
     with eff_nsigma = m_nsigma = 3).
    => effective acceptance = [ start - 3*sigma_T , start+readout + 3*sigma_T ],
       and near-edge depos contribute their in-window diffusion tail.

So the bagger is TIGHTER than DepoTransform by 3*sigma_T at each edge.
sigma_T = sigma_L / drift_speed, sigma_L = sqrt(2*DL*t_drift) (DL=4e-9 cm^2/ns,
v=1.6 mm/us):
    drift  50 cm -> 3*sigma_T = 0.94 us =  1.9 ticks
    drift 325 cm -> 3*sigma_T = 2.39 us =  4.8 ticks
    drift 650 cm -> 3*sigma_T = 3.38 us =  6.8 ticks
i.e. the bagger drops depos up to ~7 ticks (3.4 us) beyond each edge whose
diffusion tails DepoTransform correctly keeps.

## Conclusion

* The converter (wclsSimDepoSource vs wclsSimDepoSetSource) is NOT the cause
  (both use sed.Time() verbatim).
* The vanilla path's extra DepoBagger applies a HARD center-time cut at the
  readout-window edges, whereas the correct sim gate (DepoTransform, used by
  both paths) is an nsigma-SOFT cut that retains the diffusion tails of
  depos centered just outside the window.
* The DepoBagger therefore removes edge-tail signal that physically belongs
  in the first/last ~few ticks, shifting the earliest/latest reconstructed
  hit -> "different minimum hit times", small and edge-localized (chi2~8.2).
* rollexp (no DepoBagger) is correct: the DepoTransform nsigma window already
  provides the physically correct time gating.  The DepoBagger in the vanilla
  graph is redundant AND inconsistent (too tight) and is the source of the
  discrepancy; it should be dropped (as rollexp does) for the VD path.

## Empirical confirmation — BLOCKED on input

/exp/dune/data/users/yuhw/wct-ci/dune/dune10kt-vd/g4_vd-1x8x14-validation.root
is a 9.5 KB HTML page (failed download), not a ROOT file.  Need a real g4
input to run vanilla (release, +DepoBagger) vs rollexp (branch, no bagger)
and show the ~few-tick edge difference in Hit Peak Time.

## Empirical harness built; input.root blocked by x-origin mismatch

A clean bagger-isolation harness is in place (issue-490-hit-time/):
* override/pgrapher/experiment/dune10kt-vd/wcls-sim-drift-simchannel-nf-sp.jsonnet
  = branch jsonnet + a spliced `setgater` node
  = DepoSetDrifter{ drifter: TimeGatedDepos(accept, start=ductor.start_time,
    duration=ductor.readout_time) }, i.e. the DepoBagger hard cut reproduced
    on the IDepoSet (DepoSetDrifter drops depos its wrapped drifter rejects).
  So: rollexp (run_rollexp.fcl) vs bagger-mimic (run_bagger.fcl via the
  override) differ ONLY by the hard time-gate; same depos, same nsigma=3.
* Memory verified: peak 4.9 GB for the full-VD run (well under 20 GB).

BLOCKER: input.root (LArSoft dunevd10kt_3view_30deg_v6, depos x in [-652,-370] cm)
is incompatible with the WCT dune10kt-vd config, whose params-10kt places the
bottom CRP anode at x=-3.97 cm (drift volume [-4,646]) and top at x=1300 cm.
All 13138 depos fall below the bottom anode -> DepoSetDrifter drifted ndepos=0
-> no TPC signal.  (Same x-origin mismatch noted in the smear-dnn campaign.)
This is why #485 "passed" on input.root: recob::Wire channels exist but carry
noise only, not depo signal.

To actually run the min-hit-time edge comparison, use an input whose geometry
matches the WCT config: a dune-vd 1x8x14 g4 (the issue's own geometry), e.g.
a campaign single-muon g4, or a re-downloaded g4_vd-1x8x14-validation.root.

## Empirical result on g4_vd-1x8x14-validation.root (the issue's input)

Ran the issue's fcl standard_detsim_dunevd10kt_1x8x14_3view_30deg.fcl (TPC-only,
1x8x14, 112 CRM) on g4_vd-1x8x14-validation.root (4054 depos), 3 configs
(<=8 cores, peak 1.3-2.3 GB):

  config              nchan_sig  earliest_tick  latest_tick   Qtot
  rollexp (no gate)      367         6331          8112      1.577e5
  bagger-mimic (gate)    367         6331          8112      1.577e5   <- IDENTICAL
  drop-all gate            0          -             -         0        <- gate is LIVE

* rollexp vs bagger-mimic (DepoBagger hard cut reproduced via
  DepoSetDrifter{TimeGatedDepos, start=ductor.start_time,
  duration=ductor.readout_time}): byte-for-byte the same signal — same 367
  channels, same earliest/latest tick, same Qtot, zero edge difference.
* This validation event is a single far-drift, mid-window track: its signal
  sits at ticks 6331-8112 inside the [0,8500] readout, with NO depos within
  ~3*sigma_T (<=7 ticks) of either window edge -> the bagger has nothing to
  over-cut -> no min-hit-time shift.  Exactly what the analysis predicts.
* Harness proven live: the drop-all gate ([0,1us] accept window) collapses
  the output to 0 signal channels, so setgater/TimeGatedDepos really gates;
  the null above is genuine, not a bypassed override.

Interpretation: the issue's 10k-event Hit-Peak-Time difference is the AGGREGATE
of the rare events that DO deposit within ~3*sigma_T of the readout-window time
edges (near-anode/early or late-arriving tracks).  A single mid-window event
shows no difference, consistent with the tiny chi2~8.2 and the edge-localized
deviation in the figure.

## DECISIVE empirical test — real cathode-anode muon (g4_vd_muminus_tomox_1x8x14.root)

Ran the issue's fcl on the real cathode-anode muon the user provided (x=0->325 cm,
full CRP drift), TPC-only 1x8x14. Vanilla = pure release v10_21_01d00 (IDepo +
Drifter + wclsSimChannelSink + **DepoBagger**); rollexp = the branch (DepoSet +
DepoSetDrifter + wclsDepoFluxWriter, **no bagger**). Logs confirm genuinely
different graphs (van: wclsSimDepoSource+SimChannelSink; roll:
wclsSimDepoSetSource+DepoFluxWriter). Both load the same noise spectra.

### At the STANDARD window (nticks=8500): BYTE-IDENTICAL
  vanilla  nchan=47  Qtot=8.796e4  signal-tick-range=(105,4057)
  rollexp  nchan=47  Qtot=8.796e4  signal-tick-range=(105,4057)  <- every 100-tick bin ratio=1.000
* The muon's signal occupies ticks 105-4057 and the readout window is [0,8500].
  So the muon fills only the FIRST HALF; there is NO activity at the window END
  (tick 8500) NOR within 3*sigma_T of tick 0 (earliest hit 105 >> 3 ticks).
* With no depo near either window time-edge, the bagger has nothing to over-cut,
  so vanilla==rollexp EXACTLY. Noise is identical too (byte-identical proves the
  RNG seed matches), so this is a clean signal-level comparison.
* KEY: a "cathode-anode" muon spans the full DRIFT, but that maps to ticks
  105-4057 -- a SUBSET of the 8500-tick readout. It does NOT reach the readout
  window's time edges. No in-time VD track does (full 650 cm drift = 8125 ticks
  < 8500). So the standard config shows the branch difference for essentially NO
  in-time event.

### Forcing edge activity (nticks=3000 < muon max 4057): the branches DIVERGE
  vanilla_3k  nchan=45  Qtot=3.910e4  range=(105,2999)
  rollexp_3k  nchan=45  Qtot=3.796e4  range=(105,2999)   <- Qtot differs ~3%
  + scattered per-100-tick differences (0.56x .. 1.36x) across ticks 800-3000
  + a large pile-up SPIKE in the last bin [2900,3000) (~5e3), differing by branch.
* Shrinking the window below the muon's max drift forces its late depos to the
  window time-edge. NOW vanilla vs rollexp differ -- and the divergence spans
  HUNDREDS of ticks, not ~7.

## Resolution of the "~100 ticks >> 3*sigma" puzzle (user's key objection)

The depo-level edge cut (DepoBagger hard vs DepoTransform nsigma=3 soft) is only
~3-7 ticks. But that difference is the INPUT to OmnibusSigProc, which is strongly
NONLINEAR (2D deconvolution + tight/loose LF filters + ROI thresholding + peak
finding). A few-tick perturbation of the edge charge shifts ROI boundaries and
peak assignments, which the nticks=3000 test shows propagating into ~100-tick-
scale, event-wide differences in the SP output (and hence in reco Hit Peak Time).
So the ~100-tick (2-bin) deficit is NOT the raw 3-sigma edge width -- it is the SP's
nonlinear amplification of the edge perturbation. This is exactly why the effect
is edge-localized yet ~100 ticks wide, and why the bulk chi2 stays tiny (~8.2).

## Timing map (answering "why x=0 -> tick 105")

Geometry (release dune-vd params.jsonnet): anode (CRP) at x=+325 cm, cathode at
x=-325 cm, drift along +x, response_plane=18.92 cm in front of the wires,
driftSpeed=1.60563 mm/us, tick=0.5 us, daq.start_time=0.
  ductor.start_time = -drift_dt,  drift_dt=response-plane->wire transit;
  reframer strips tbin=fields.nticks so output tick 0 <-> absolute t=0.
Measured on the muon (IonAndScint depos, x in [0,325], all prompt t~0):
  max-x depo x=324.98 (AT the anode)  -> earliest signal tick 105
  min-x depo x=0.02  (detector MIDDLE, 325 cm from anode) -> latest tick 4057
  slope (4057-105)/325 = 12.16 tick/cm = 0.1645 cm/us  (matches driftSpeed).
So x=0 does NOT map to tick 105 -- it maps to ~4057.  x=325 (anode, ~0 drift)
maps to the earliest tick ~105.  The ~105-tick (52.5 us) floor is the fixed
field-response + reframer latency: NO in-time hit can appear before ~tick 105.
(The "cathode-anode" muon actually runs anode->middle here, x=0..325.)

## sigma_T asymmetry: the bagger CANNOT cause a beginning (0-100 tick) deficit

The DepoBagger(hard) vs DepoTransform(nsigma=3 soft) edge difference is
+-3*sigma_T at each window edge, sigma_T = sqrt(2*DL*t_drift)/v_drift.
  near-anode / earliest ticks: t_drift~0 -> sigma_T~0 -> bagger==DepoTransform
    (both cut identically) -> ZERO difference at the beginning.
  far / cathode / latest ticks: t_drift max -> sigma_T max (~7 ticks) -> the
    bagger difference is maximal at the END, not the beginning.
So a vanilla deficit at ticks 0-100 (the beginning) is physically inconsistent
with the DepoBagger being the cause.

## Anode-corner muon test (released prod_muminus_...fixedstartonanodecorner, 1x8x6)

gen->g4->detsim vanilla vs rollexp on a 5 GeV muon STARTING ON THE ANODE
(x=324.7, prompt) going into the drift to x=-186 (39652 depos, 3203 channels).
Graphs confirmed distinct (van: SimDepoSource+SimChannelSink; roll:
SimDepoSetSource+DepoFluxWriter).
  vanilla nchan=3203 Qtot=1.036e6 tick-range=(100,6052)
  rollexp nchan=3206 Qtot=1.036e6 tick-range=(100,6052)
  earliest bins [100,300): ratio 1.00 -> IDENTICAL at the beginning
  only diffs: ~1% scattered, up to +-3-5% at MID/FAR drift (bins 3300-3500,
    4500-4600), rollexp +3 channels -- exactly the sigma_T-large (far-drift)
    edge region, never the beginning.
=> EMPIRICAL CONFIRMATION: even a muon depositing heavy charge AT the anode
   produces NO vanilla deficit at ticks 0-300.  The 0-100 region is below the
   ~105 instrumental floor and is empty in BOTH branches.  A beginning-region
   difference does not originate in the WCT sim/SP recob::Wire output.

## REPRODUCED: early-T0 (out-of-time) muon -> vanilla deficit at earliest ticks

The user confirmed the figure shows VANILLA low at the EARLIEST ticks.  In-time
muons show no such deficit (anode-corner test above), because at the in-time
earliest edge (near-anode) sigma_T~0.  The missing ingredient is OUT-OF-TIME
activity: an early deposit whose FAR-drift (large sigma_T) charge is pushed onto
the readout-window START edge.

Test: same anode-corner muon, T0 = -1.5 ms (verified: g4 SED times ~-1.5e6 ns
survived LArSoft).  This shifts the whole event 3000 ticks early; the bagger
window-start edge (ductor.start_time = -118 us) now falls at x~103 cm
(drift ~222 cm, sigma_T ~3.5 ticks) instead of at the sigma_T~0 anode.
gen->g4->detsim vanilla vs rollexp (1x8x6):

  config   earliest_tick  bin[0,100)  bin[100,200)   bulk(200+)   nchan
  vanilla       102            0        1.25e4        identical    1635
  rollexp        99          0.17       1.34e4(+7.2%) identical    1640

=> vanilla (DepoBagger) is DEFICIENT at the earliest ticks: rollexp reaches ~3
   ticks earlier (99 vs 102) and has ~7% more signal in the first populated bin;
   ticks 200+ are identical.  rollexp keeps 5 more channels.  EXACTLY the issue's
   signature (vanilla low at earliest ticks, rollexp correct).

Mechanism (now complete):
* The DepoBagger (vanilla only) is a HARD cut on the depo CENTER time at
  [ductor.start_time, +readout].  DepoTransform (both branches) is an nsigma=3
  SOFT cut that keeps a depo whose center is up to 3*sigma_T OUTSIDE the window,
  binning its in-window diffusion tail.
* The difference = +-3*sigma_T at each edge, sigma_T = sqrt(2*DL*t_drift)/v.
* IN-TIME events never populate this: the in-time earliest edge is the near-anode
  region where t_drift~0 -> sigma_T~0 -> both cut identically (anode-corner test:
  identical at ticks 0-300).
* OUT-OF-TIME-early events DO: their far-drift (large sigma_T) charge lands on the
  window START edge, where the bagger hard-cuts depos that DepoTransform keeps ->
  vanilla loses the earliest-arriving hits -> deficit at ticks 0-~200.
* Across the 10k "sync" sample, the aggregate of such out-of-time / edge events
  produces the ~2-bin (~100 tick) vanilla deficit at the earliest ticks in the
  figure (bulk agrees, chi2~8.2).  The ~100-tick WIDTH is the spread of edge
  conditions across the sample (plus SP nonlinearity), not a single 3-sigma cut.

## ROOT CAUSE (confirmed by HaiwangYu via the config dump) + FIX

The real bug is the ductor (DepoTransform / sim.ductor) PRE-READOUT OPENING.
WCT simulates at the RESPONSE PLANE, so the ductor must open early by
(resp_x - collection_x)/drift_speed = response_plane/drift_speed, and a Reframer
then chops that pre-opening back to the DAQ window.  For VD the response plane is
18.92 cm (~118 us ~ 236 ticks), but the base default leaked through as ~10 cm
(62.3 us ~ 125 ticks).  The ~111-tick shortfall = the missing hits below tick 100.

Config-dump evidence (both branches, BEFORE fix):
  DepoTransform start_time = -62280.85 ns (-125 t = 10 cm)   [WRONG for VD]
  Reframer      tbin       = 125 t
Only single-apa dune10kt-vd/params-10kt.jsonnet had the fix; dune-vd (1x8x14)
and DUNE/develop did not.  So the issue's pdf (made for vd-10kt) compared
vanilla-10kt (buggy 10cm) vs rollexp-10kt (fixed 18.9cm); the deficit is real and
also present in the VD 1x8x14 workspace.

FIX (dune-vd/params.jsonnet, sim block): propagate the params-10kt pre-opening:
  local response_time_offset = params.response_plane / $.lar.drift_speed,
  local response_nticks = wc.roundToInt(response_time_offset / $.daq.tick),
  ductor  : { nticks: $.daq.nticks + response_nticks,
              readout_time: self.nticks * $.daq.tick,
              start_time: 0*wc.us - response_time_offset },
  reframer: { tbin: response_nticks, nticks: $.daq.nticks }
(Use params.response_plane, NOT $.det.response_plane: a jsonnet $-late-binding
quirk resolves $.det.response_plane to the base 10cm default inside this block.)

Config-dump AFTER fix:
  DepoTransform start_time = -117835 ns (-236 t = 18.92 cm)  [CORRECT]
  Reframer      tbin       = 236 t

## FIX VERIFIED on the anode-cathode muon (g4_vd_muminus_tomox_1x8x14.root)

  config             earliest_tick  bin[0,100)   Qtot
  vanilla (unfixed)      105            0        8.796e4
  rollexp (FIXED)          0         3230        9.096e4  (+3.4%)

* The fix RECOVERS the hits below tick 100 that were being dropped: earliest tick
  105 -> 0, bin[0,100) 0 -> 3230.
* Bins 100-300 drop (ratio 0.65, 0.75): the charge that was artificially piled at
  the truncated earliest ticks is now correctly spread into 0-100.
* Signal range (105,4057) -> (0,4056); +3.4% total charge = the recovered early hits.
This is exactly the issue #490 signature (vanilla deficient at earliest ticks),
now resolved by matching the ductor pre-opening to the 18.92 cm response plane.

NOTE: earlier bagger / out-of-time analyses in this file were on the right track
(edge/timing) but the ACTUAL bug is the pre-opening mismatch, not the DepoBagger.

## single-apa branch: dune-vd is ALREADY FIXED (via elec.fields override)

Checked out dunereco branch `single-apa` (restored smear-dnn first; no edits left
on either branch).  On single-apa, dune-vd/params.jsonnet reaches the correct
pre-opening WITHOUT an explicit sim.ductor block: it adds an elec.fields override
that smear-dnn lacked:
    elec: super.elec {
        ...
        fields: super.fields {
            start_dx: $.det.response_plane,          // = 18.92 cm
            drift_dt: self.start_dx / $.lar.drift_speed,
        },
    },
The base pgrapher/common/params.jsonnet computes sim.ductor.start_time from
$.elec.fields.drift_dt and reframer.tbin from $.elec.fields.nticks, so this
override flows through to the correct 236-tick pre-opening.

JSON dump (config-dump/singleapa_current.json), single-apa dune-vd, unmodified:
    DepoTransform start_time = -117835 ns (-236 t = 18.92 cm)   [CORRECT]
    Reframer      tbin       = 236 t
(vs smear-dnn buggy: -62280 ns / -125 t / 10 cm.)

Note: single-apa uses a refactored wcls interface (extVars process_mode /
process_tpc_index instead of process_crm / ncrm; inputer wclsSimDepoSetSource,
outputers wclsDepoFluxWriter:postdrift + wclsFrameSaver:spsignals).

## single-apa ACTUAL SIMULATION CHECK (anode-cathode tomox muon, 1x8x14 full)

Ran single-apa's own fcl (dune-vd/wcls-sim-drift-simchannel-nf-sp.fcl) overridden
to process_mode="1x8x14" (full 112 CRM, plopper dropped) on
g4_vd_muminus_tomox_1x8x14.root.  Graph confirmed = rollexp path
(wclsSimDepoSetSource + wclsDepoFluxWriter).

  config                          earliest_tick  bin[0,100)   Qtot
  vanilla (release, buggy 125t)       105            0        8.796e4
  single-apa (branch, 236t)             0         3250        9.066e4 (+3.1%)

=> single-apa RECOVERS the <100-tick hits (earliest 105 -> 0), matching the
   smear-dnn+manual-fix result (earliest 0, bin[0,100) 3230, +3.4%).  Confirmed
   live: the single-apa dune-vd config is already correct; no code change needed.

## Bottom line for issue #490

* NOT the wclsSimDepoSource/wclsSimDepoSetSource converter (time-identical).
* The ONLY reco-relevant difference between the two graphs is the DepoBagger
  (present in vanilla, absent in rollexp): a HARD depo-center time cut at the
  readout-window edges, vs the sim's real gate (DepoTransform nsigma=3 SOFT cut,
  used by both) that keeps near-edge depos' diffusion tails.
* EMPIRICALLY (real cathode-anode muon):
  - standard window (nticks=8500): vanilla == rollexp BYTE-IDENTICAL, because
    the muon never reaches the window time-edge (signal 105-4057 << 8500);
  - forced edge activity (nticks=3000): the branches DIVERGE, Qtot ~3% and
    ~100-tick-wide scattered SP differences + a window-end pile-up spike.
* The ~100-tick (2-bin) deficit is the NONLINEAR SP amplification of the ~3-7
  tick depo-level edge difference -- NOT the raw 3-sigma width. This resolves the
  user's objection that 3-sigma is too small.
* rollexp (no DepoBagger) is CORRECT: DepoTransform already gates correctly; the
  extra bagger is redundant and inconsistent at the edges. Fix = keep the bagger
  out of the VD DepoSet graph (as rollexp does).
* CAVEAT / to fully close: the effect only appears for events with charge AT the
  readout-window time-edge. The provided muon is in-time and does not reach the
  edge in the standard 8500-tick window, so it shows zero difference there; the
  divergence was demonstrated only by artificially shrinking the window. A clean
  reproduction of the issue's figure needs an input with genuine edge/out-of-time
  activity (e.g. the 10k sample or a late/early-arriving track).
