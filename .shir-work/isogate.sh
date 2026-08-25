#!/usr/bin/env bash
set -e
ROOT=/home/llm/sh2loop
VBIN="$ROOT/.shir-verify-target/debug/debashc"
DEBASHC="$VBIN" DEBASHC_TRANSFORMS=noop "$ROOT/fail-shir" >/dev/null 2>&1
# now scan: for each non-bashfree file, dump callsites
python3 - "$VBIN" "$ROOT" <<'PY'
import subprocess,sys,os,json
vb=sys.argv[1]; root=sys.argv[2]
fail=os.path.join(root,'.shir_failures.tsv')
targets=[]
for line in open(fail):
    f=line.rstrip('\n').split('\t')
    if len(f)>1 and f[1] not in ('0','ERR'):
        targets.append(f[0][:-3])
import tempfile
for t in targets:
    p=os.path.join(root,'sh2perl/examples',t+'.sh')
    if not os.path.exists(p): continue
    a1=subprocess.run([vb,'--shir',p],capture_output=True,text=True).stdout
    if '"type":"Program"' not in a1: continue
    tmp=tempfile.NamedTemporaryFile('w',delete=False,suffix='.json',dir=root)
    tmp.write(a1); tmp.close()
    perl=subprocess.run([vb,'--shir-in-perl',tmp.name],capture_output=True,text=True).stdout
    os.unlink(tmp.name)
    n=len(re.findall(r"system\(['\"]bash['\"]", perl)) if 're' in dir() else 0
    import re
    n=len(re.findall(r"system\(['\"]bash['\"]", perl))
    if n==0: continue
    print(f"===== {t}.sh ({n}) =====")
    for m in re.finditer(r"system\(['\"]bash['\"],\s*['\"]-c['\"],\s*(q\{.*?\}\)|.*?\)\s*\))",perl,re.S):
        line=m.group(0).replace('\n',' ')
        print("  "+line[:160])
PY
