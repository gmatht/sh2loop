import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/006_misc.sh", []);
sh2._setAllowlist(["/usr/bin/env","bash","Subshell","inside-subshell","Simple","pipeline","alpha","beta","exit:"]);
process.stdout.write("== Subshell ==\n");
await sh2.subshell(async () => sh2.builtin("echo", ["inside-subshell"]));
process.stdout.write("== Simple pipeline ==\n");
sh2.grepText("alpha beta" + "\n", ["beta"], false);
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
