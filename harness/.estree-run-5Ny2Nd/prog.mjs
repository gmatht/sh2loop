import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/063_06_complex_pipeline_background.sh", []);
sh2._setAllowlist(["/bin/bash","6.","Complex","pipeline","with","background","processes","and","subshells","1","Starting","2","Processing","All","done","exit:"]);
sh2.background(async () => { await sh2.subshell(async () => { await sh2.exec("sleep", ["1"]); sh2.builtin("echo", [`Starting`]); }); });
sh2.background(async () => { await sh2.subshell(async () => { await sh2.exec("sleep", ["2"]); sh2.builtin("echo", [`Processing`]); }); });
await sh2.exec("wait", []);
process.stdout.write("All done\n"), (sh2.lastExit = 0), true;
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
