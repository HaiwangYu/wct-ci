import ROOT, numpy as np, sys
ROOT.gROOT.SetBatch(True); ROOT.gErrorIgnoreLevel=ROOT.kError
for h in ["gallery/Event.h","lardataobj/RecoBase/Wire.h","canvas/Utilities/InputTag.h"]:
    ROOT.gInterpreter.ProcessLine(f'#include "{h}"')

def prof(fname, tag="gauss"):
    fn=ROOT.vector(ROOT.string)(); fn.push_back(fname)
    ev=ROOT.gallery.Event(fn)
    ws=ev.getValidHandle[ROOT.vector(ROOT.recob.Wire)](ROOT.art.InputTag("tpcrawdecoder",tag))
    P=None; n=0; q=0.0
    for w in ws.product():
        s=np.abs(np.asarray(w.Signal(),dtype=float))
        if P is None: P=np.zeros(len(s))
        if s.sum()==0: continue
        n+=1; q+=s.sum(); P[:len(s)]+=s
    return P,n,q

fa,fb,la,lb = sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
Pa,na,qa=prof(fa); Pb,nb,qb=prof(fb)
def nz(P):
    i=np.nonzero(P)[0]; return (int(i.min()),int(i.max())) if len(i) else (None,None)
ea=nz(Pa); eb=nz(Pb)
print(f"{la:10s} nchan={na:5d} Qtot={qa:12.4g} signal-tick-range={ea}")
print(f"{lb:10s} nchan={nb:5d} Qtot={qb:12.4g} signal-tick-range={eb}")
n=min(len(Pa),len(Pb))
# per-100-tick binned totals to locate the difference
edges=np.arange(0,n+100,100)
print("\ntick-bin   %-10s %-10s   ratio(%s/%s)"%(la,lb,lb,la))
for i in range(len(edges)-1):
    a=Pa[edges[i]:edges[i+1]].sum(); b=Pb[edges[i]:edges[i+1]].sum()
    if a>0 or b>0:
        r = b/a if a>0 else float('inf')
        mark = "  <== differ" if (a>0)!=(b>0) or (a>0 and abs(1-r)>0.05) else ""
        print(f"[{edges[i]:5d},{edges[i+1]:5d})  {a:10.3g} {b:10.3g}   {r:6.3f}{mark}")
