import ROOT, numpy as np
ROOT.gROOT.SetBatch(True); ROOT.gErrorIgnoreLevel=ROOT.kError
f=ROOT.TFile.Open("/exp/dune/app/users/yuhw/wct-ci/dune/dune-vd/g4_vd_muminus_tomox_1x8x14.root")
t=f.Get("Events")
brs=[b.GetName() for b in t.GetListOfBranches() if 'SimEnergyDeposit' in b.GetName()]
print("SED branches:"); [print("  ",b) for b in brs]
for h in ["gallery/Event.h","lardataobj/Simulation/SimEnergyDeposit.h","canvas/Utilities/InputTag.h"]:
    ROOT.gInterpreter.ProcessLine(f'#include "{h}"')
fn=ROOT.vector(ROOT.string)(); fn.push_back("/exp/dune/app/users/yuhw/wct-ci/dune/dune-vd/g4_vd_muminus_tomox_1x8x14.root")
ev=ROOT.gallery.Event(fn)
# derive label from first SED branch: <type>_<label>_<instance>_<process>.
lab=brs[0].split('_'); tag=ROOT.art.InputTag("IonAndScint","")
print("using tag: IonAndScint")
h=ev.getValidHandle[ROOT.vector(ROOT.sim.SimEnergyDeposit)](tag)
xs=[];ts=[];es=[]
for s in h.product():
    p=s.MidPoint(); xs.append(p.x()); ts.append(s.Time()); es.append(s.Energy())
xs=np.array(xs);ts=np.array(ts);es=np.array(es)
print(f"nSED={len(xs)}  x[{xs.min():.1f},{xs.max():.1f}]cm  t[{ts.min():.3f},{ts.max():.3f}]ns  E={es.sum():.1f}MeV")
# depo closest to anode (max x) and its time
i=np.argmax(xs); print(f"max-x depo: x={xs[i]:.2f}cm t={ts[i]:.3f}ns")
i2=np.argmin(xs); print(f"min-x depo: x={xs[i2]:.2f}cm t={ts[i2]:.3f}ns")
# drift model: anode=325, resp_plane~=316, v=0.1645 cm/us. output tick ~= (t_ns/1000 + (325 - x)/... )/0.5
