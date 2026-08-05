import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/test-double-bracket.sh", []);
sh2._setAllowlist(["/bin/bash","if","-n","foo","then","yes","fi"]);
if (sh2.test(" -n \"$(echo foo)\"")) { process.stdout.write("yes\n"); } else { sh2.lastExit = 0; }

await sh2._finish();
