import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/tmp/loop_test10.sh", []);
sh2._setAllowlist(["for","f","in",".sh","do","done"]);
let f = "";
await sh2.forLoopBatch(["\u0001SH2GLOB\u0001*.sh"], (f) => { process.stdout.write([String(f)].join(" ") + "\n"); }, 1024);

await sh2._finish();
