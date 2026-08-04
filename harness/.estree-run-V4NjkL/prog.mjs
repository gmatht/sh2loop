import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/tmp/bench_runner.sh", []);
sh2._setAllowlist(["/bin/sh","setup","__count","0","while","-lt","100000","do","test","n","__count+1","done","cleanup"]);
let __count = 0;
sh2.functions.set("setup", () => ((sh2.lastExit = 0), true)), true;
__count = 0;
while (__count < 100000) { process.stdout.write("test\n"); __count = __count + 1; }
sh2.functions.set("cleanup", () => ((sh2.lastExit = 0), true)), true;

await sh2._finish();
