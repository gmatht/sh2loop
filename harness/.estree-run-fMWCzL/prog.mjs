import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/096_head_procsub.sh", []);
sh2._setAllowlist(["/bin/bash","while","do","1","done","exit:"]);
await sh2.redirect(async () => sh2.builtin("head", []), [{fd: 0, mode: "herestring", target: await sh2.capture(async () => { await sh2.whileLoop(async () => ((sh2.lastExit = 0), true), async () => { sh2.builtin("echo", ["."]); await sh2.exec("sleep", ["1"]); }); })}]);
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
