```bash
wire-cell -l stdout -L debug -c check_pdsp_sim_sp.jsonnet -C Nbit=12 -C elecGain=14 -C wire_col_nsigma=10.0 -C use_dnnroi=true -V input=depos.tar.bz2 -V output=pr455.tar.bz2
wirecell-plot frame -n wave --interactive -o pr444-test0/frame.pdf pr444-test0/test.tar.bz2

wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 700 --chmax 701 --interactive test.tar.bz2 0.33.0.tar.bz2
wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 700 --chmax 701 --interactive 0.33.0.tar.bz2 pr455.tar.bz2

wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 1230 --chmax 1231 --interactive pr445-dnn.tar.bz2 pr444-test0/test.tar.bz2
wirecell-plot comp1d -n wave -t orig -o tmp.pdf --chmin 2280 --chmax 2281 --interactive pr445-dnn.tar.bz2 pr444-test0/test.tar.bz2
rename test pr445-triton *
```


```bash
valgrind --tool=massif --stacks=yes 
```