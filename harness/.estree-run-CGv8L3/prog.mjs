import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/092_for_arith_func.sh", []);
sh2._setAllowlist(["/bin/bash","For","loop","with","function","and","arithmetic","factorial","n","1","result","i","for","2","i++","do","done","5","6"]);
let result = 0;
sh2.functions.set("factorial", () => { sh2.builtin("local", ["n=$1"]); (result = 1), (sh2.lastExit = 0), true; sh2.builtin("local", ["i"]); sh2.cstyleForSync(" i = 2; i <= n; i++ ", () => { result = result * (Number(sh2.getVar("i")) || 0); }); process.stdout.write([String(result)].join(" ") + "\n"), (sh2.lastExit = 0), true; }), true;
sh2.fnCall("factorial", ["5"]);
sh2.fnCall("factorial", ["6"]);

await sh2._finish();
