// This is a main entry point for configuring a wire-cell CLI job to
// simulate protoDUNE-SP.  It is simplest signal-only simulation with
// one set of nominal field response function.  It excludes noise.
// The kinematics are a mixture of Ar39 "blips" and some ideal,
// straight-line MIP tracks.
//
// Output is a Python numpy .npz file.

local g = import 'pgraph.jsonnet';
local f = import 'pgrapher/common/funcs.jsonnet';
local wc = import 'wirecell.jsonnet';
local io = import 'pgrapher/common/fileio.jsonnet';

local output = std.extVar('output');

local tools_maker = import 'pgrapher/common/tools.jsonnet';
local base = import 'pgrapher/experiment/pdsp/simparams.jsonnet';
local params = base {
  lar: super.lar {
    // Longitudinal diffusion constant
    // DL: std.extVar('DL') * wc.cm2 / wc.s,
    DL: 4.0 * wc.cm2 / wc.s,
    // Transverse diffusion constant
    // DT: std.extVar('DT') * wc.cm2 / wc.s,
    DT: 8.8 * wc.cm2 / wc.s,
    // Electron lifetime
    // lifetime: std.extVar('lifetime') * wc.ms,
    lifetime: 10.4 * wc.ms,
    // Electron drift speed, assumes a certain applied E-field
    // drift_speed: std.extVar('driftSpeed') * wc.mm / wc.us,
    drift_speed: 1.565 * wc.mm / wc.us,
  },
};

local tools_all = tools_maker(params);
local tools = tools_all {
    anodes: [tools_all.anodes[0]],
    // dft : {
    //     type: "cuFftDFT",
    // },
};

local sim_maker = import 'pgrapher/experiment/pdsp/sim.jsonnet';
local sim = sim_maker(params, tools);

local nanodes = std.length(tools.anodes);
local anode_iota = std.range(0, nanodes - 1);


local apa6 = {
    // tail: wc.point(0.5, 4, 2.4, wc.m),
    // head: wc.point(3.5, 2, 4.5, wc.m),
    tail: wc.point(0.5, 2, 4.5, wc.m),
    head: wc.point(0.5, 2, 4.5, wc.m),
};
local tracklist = [
    {
        time: 0 * wc.us, 
        charge: -5000, // 5000 e/mm
        ray: apa6,
    },
];

local depos = sim.tracks(tracklist, step=1.0 * wc.mm);

local bagger = sim.make_bagger();

local drifter = sim.drifter;

// signal plus noise pipelines
//local sn_pipes = sim.signal_pipelines;
local sn_pipes = sim.splusn_pipelines;

local magoutput = output+".root";
local magnify = import 'pgrapher/experiment/pdsp/magnify-sinks.jsonnet';
local sinks = magnify(tools, magoutput);

local sio_sinks = g.pnode({
        type: "FrameFileSink",
        data: {
            outname: output+".tar.bz2", // "frames.tar.bz2",
            tags: ["orig"],
            digitize: false,
        },
    }, nin=1, nout=0);

local multipass = [
    g.pipeline([
        sn_pipes[n],
        sinks.orig_pipe[n],
        // sio_sinks[n],
    ], 'multipass%d' % n)
  for n in anode_iota
];
local outtags = ['orig%d' % n for n in anode_iota];
local bi_manifold = f.fanpipe('DepoSetFanout', multipass, 'FrameFanin', 'sn_mag_nf', outtags);
// local bi_manifold = f.fanpipe('DepoFanout', multipass, 'FrameFanin', 'sn_mag_nf', outtags);

local retagger = g.pnode({
  type: 'Retagger',
  data: {
    // Note: retagger keeps tag_rules an array to be like frame fanin/fanout.
    tag_rules: [{
      // Retagger also handles "frame" and "trace" like fanin/fanout
      // merge separately all traces like gaussN to gauss.
      frame: {
        '.*': 'orig',
      },
      merge: {
        'orig\\d': 'daq',
      },
    }],
  },
}, nin=1, nout=1);

//local frameio = io.numpy.frames(output);
local sink = sim.frame_sink;

local graph = g.pipeline([depos, drifter, bagger, bi_manifold, retagger, sio_sinks]);
local plugins = [ "WireCellSio", "WireCellGen", "WireCellSigProc","WireCellApps", "WireCellPgraph", "WireCellTbb", "WireCellRoot"/*, "WireCellCuda"*/];

// Pgrapher or TbbFlow
local engine = "Pgrapher";
local app = {
  type: 'Pgrapher',
  data: {
    edges: g.edges(graph),
  },
};

local cmdline = {
    type: "wire-cell",
    data: {
        plugins: plugins,
        apps: ["Pgrapher"],
    }
};


// Finally, the configuration sequence which is emitted.
[cmdline] + g.uses(graph) + [app]
