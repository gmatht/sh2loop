import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/073_trap_signal.sh", []);
sh2._setAllowlist(["/bin/bash","Interrupted","INT","Trap","exit:"]);
sh2.builtin("trap", ["echo \"Interrupted\"", "INT"]);
process.stdout.write("Trap set\n"), (sh2.lastExit = 0), true;
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
