```bash
wire-cell -l stdout -L debug -c check_pdsp_sim_sp.jsonnet -V input=depos.tar.bz2 -V output=test.tar.bz2
wirecell-plot frame -n wave --interactive -o 0.29.3.pdf 0.29.3.tar.bz2
wirecell-plot frame -n wave --interactive -o test.pdf test.tar.bz2
wirecell-plot comp1d -n wave -o tmp.pdf --chmin 700 --chmax 701 --interactive 0.29.3.tar.bz2 test.tar.bz2
wirecell-plot comp1d -n wave -o tmp.pdf --chmin 1230 --chmax 1231 --interactive 0.29.3.tar.bz2 test.tar.bz2
rename test rc-0.30.0 *
```


wirecell-plot comp1d -n wave -o tmp.pdf --chmin 700 --chmax 701 --interactive rc-0.30.0.tar.bz2 test.tar.bz2