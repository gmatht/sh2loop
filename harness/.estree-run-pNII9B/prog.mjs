import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/dollar-question.sh", []);
sh2._setAllowlist(["/bin/sh","Tests","status","of","last","exit:"]);
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
