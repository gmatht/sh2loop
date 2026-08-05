import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/test-expr-long-option.sh", []);
sh2._setAllowlist(["/bin/bash","Tests","--long-option","style","tokens","in","test","expressions","if","--view","then","view","mode","fi"]);
if (sh2.test("\"$*\"=*--view*")) { process.stdout.write("view mode\n"); } else { sh2.lastExit = 0; }

await sh2._finish();
