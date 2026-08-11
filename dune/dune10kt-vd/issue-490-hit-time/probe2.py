import ROOT, numpy as np, sys
ROOT.gROOT.SetBatch(True); ROOT.gErrorIgnoreLevel=ROOT.kError
for h in ["gallery/Event.h","lardataobj/Simulation/SimEnergyDeposit.h","canvas/Utilities/InputTag.h"]:
    ROOT.gInterpreter.ProcessLine(f'#include "{h}"')
fn=ROOT.vector(ROOT.string)(); fn.push_back(sys.argv[1])
ev=ROOT.gallery.Event(fn)
h=ev.getValidHandle[ROOT.vector(ROOT.sim.SimEnergyDeposit)](ROOT.art.InputTag("IonAndScint",""))
X=[];Y=[];Z=[];T=[]
for s in h.product():
    p=s.MidPoint(); X.append(p.x());Y.append(p.y());Z.append(p.z());T.append(s.Time())
X,Y,Z,T=map(np.array,(X,Y,Z,T))
print(f"nSED={len(X)} x[{X.min():.1f},{X.max():.1f}] y[{Y.min():.1f},{Y.max():.1f}] z[{Z.min():.1f},{Z.max():.1f}] t[{T.min():.2f},{T.max():.2f}]ns")
i=np.argmax(X); print(f"max-x(anode): x={X[i]:.2f} y={Y[i]:.1f} z={Z[i]:.1f} t={T[i]:.2f}")
