Signal:
```bash
wire-cell -l stdout -L debug -c check_pdsp_sim.jsonnet  -C Nbit=12 -C elecGain=14 -C wire_col_nsigma=10.0 -V input=depos.tar.bz2 -V output=test.tar.bz2
wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 700 --chmax 701 --interactive test.tar.bz2 test.tar.bz2

wirecell-plot frame -n wave --interactive test.tar.bz2 -o tmp.pdf
wirecell-plot comp1d -n spec --chmin 1600 --chmax 2080 --interactive -o tmp.pdf --transform="median" run1.tar.bz2 test.tar.bz2
wirecell-plot comp1d -n wave --chmin 700 --chmax 701 --interactive -o tmp.pdf --transform="median" run1.tar.bz2 test.tar.bz2
wirecell-plot comp1d -n wave --chmin 2300 --chmax 2301 --interactive -o tmp.pdf --transform="median" run1.tar.bz2 test.tar.bz2
```

```bash
wirecell-gen depo-line -f -3477*mm,1000*mm,1000*mm -l -3477*mm,1000*mm,1010*mm -o x3744mm.npz
wire-cell -l stdout -L debug -c check_pdsp_sim.jsonnet  -C Nbit=12 -C elecGain=14 -C wire_col_nsigma=10.0 -V input=x3744mm.npz -V output=test.tar.bz2 >& log
wirecell-plot frame -n wave --interactive test.tar.bz2 -o tmp.pdf
```

Noise:
```bash
wire-cell -l stdout -L debug -c check_pdsp_noise.jsonnet -V output=noise-22154a5 >& 22154a5.log
wirecell-plot comp1d -n spec --chmin 0 --chmax 800 --interactive -o tmp.pdf --transform="median" frames-0.20.0.tar.bz2 frames-22154a5.tar.bz2
wirecell-plot channel-correlation frames-9485256.tar.bz2 corr-u.9485256.pdf --chmin 0 --chmax 100 --interactive
```

```bash
wire-cell -l test-addnoise.log -L debug -c test-addnoise.jsonnet -A outfile="test-addnoise-0.23.0.tar.bz2"
wirecell-plot comp1d -n spec --chmin 0 --chmax 800 --interactive -o tmp.pdf --transform="median" frames-0.20.0.tar.bz2 frames-bc9f0a2.tar.bz2
```
