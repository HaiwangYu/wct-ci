import json,collections
van=json.load(open('/exp/dune/data/users/yuhw/wct-ci/dune/dune10kt-vd/issue-490-hit-time/config-dump/vanilla.json'))
roll=json.load(open('/exp/dune/data/users/yuhw/wct-ci/dune/dune10kt-vd/issue-490-hit-time/config-dump/rollexp.json'))
def types(cfg):
    c=collections.Counter()
    for n in cfg:
        if isinstance(n,dict) and 'type' in n: c[n['type']]+=1
    return c
tv,tr=types(van),types(roll)
print("=== node-type counts (type: van -> roll) ===")
for t in sorted(set(tv)|set(tr)):
    a,b=tv.get(t,0),tr.get(t,0)
    mark=' <== DIFF' if a!=b else ''
    if a!=b or t in ('DepoBagger','Drifter','DepoSetDrifter','Reframer','DepoTransform','wclsSimDepoSource','wclsSimDepoSetSource','wclsSimChannelSink','wclsDepoFluxWriter','wclsFrameSaver'):
        print(f"  {t:32s} {a:4d} -> {b:4d}{mark}")
# timing fields anywhere
TK={'start_time','readout_time','tick','tbin','toffset','nticks','reference_time','window_start','window_duration','start','duration','period','gate','tags','fill'}
def timing(cfg,label):
    seen={}
    for n in cfg:
        if not isinstance(n,dict): continue
        t=n.get('type','?'); d=n.get('data',{})
        if not isinstance(d,dict): continue
        rel={k:d[k] for k in d if k in TK}
        if rel:
            key=t  # collapse per-type (they repeat per CRM)
            if key not in seen: seen[key]=rel
    return seen
sv,sr=timing(van,'van'),timing(roll,'roll')
print("\n=== timing fields per node type ===")
for t in sorted(set(sv)|set(sr)):
    a=sv.get(t); b=sr.get(t)
    if a!=b:
        print(f"  {t}:\n     van : {a}\n     roll: {b}")
    else:
        print(f"  {t}: {a}  (same)")
