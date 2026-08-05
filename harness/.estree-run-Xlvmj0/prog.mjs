import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/089_for_in_arith.sh", []);
sh2._setAllowlist(["/bin/bash","For","loop","with","arithmetic","total","0","for","i","in","1","2","3","4","5","do","+","done"]);
let total = 0;
let i = 0;
total = 0;
for (let i of [].concat("1", "2", "3", "4", "5")) { i = Number(i); total = total + i; }
process.stdout.write([String(`total=${total}`)].join(" ") + "\n");

await sh2._finish();
