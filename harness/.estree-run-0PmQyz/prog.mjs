import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/064_04_extended_glob_patterns.sh", []);
sh2._setAllowlist(["/bin/bash","4.","Extended","glob","patterns","with","shopt","-s","extglob","nocasematch","enabled","exit:"]);
sh2.shoptState.set("extglob", true), true;
sh2.shoptState.set("nocasematch", true), true;
process.stdout.write("Extended glob patterns enabled\n"), (sh2.lastExit = 0), true;
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
