import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/dollar-minus.sh", []);
sh2._setAllowlist(["/bin/sh","Tests","-","current","shell","options","options:"]);
process.stdout.write([String(`options: ${"hB"}`)].join(" ") + "\n");

await sh2._finish();
