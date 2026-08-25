f() { local msg="inner"; echo "$msg"; }
g() { local msg="outer"; f; echo "$msg"; }
g
