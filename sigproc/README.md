```bash
wire-cell -l stdout -L debug -c check_pdsp_sim_sp.jsonnet -C Nbit=12 -C elecGain=14 -C wire_col_nsigma=10.0 -V input=depos.tar.bz2 -V output=test.tar.bz2
wirecell-plot frame -n wave --interactive -o 0.29.3.pdf 0.29.3.tar.bz2
wirecell-plot frame -n wave --interactive -o pr445-trad.pdf pr445-trad.tar.bz2
wirecell-plot frame -n wave --interactive -o test.pdf test.tar.bz2
wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 700 --chmax 701 --interactive pr445-dnn.tar.bz2 test.tar.bz2
wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 1230 --chmax 1231 --interactive pr445-dnn.tar.bz2 test.tar.bz2
wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 2280 --chmax 2281 --interactive pr445-dnn.tar.bz2 test.tar.bz2
rename test pr445 *
```


wirecell-plot comp1d -n wave -o tmp.pdf --chmin 700 --chmax 701 --interactive rc-0.30.0.tar.bz2 test.tar.bz2