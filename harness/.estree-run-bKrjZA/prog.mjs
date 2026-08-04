import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/sed-backtick.sh", []);
sh2._setAllowlist(["/bin/sh","sed","in","backtick","substitution","-","generates","open3","with","builtin","RESULT","-n","1p","somefile"]);
let RESULT = "";
RESULT = await sh2.capture(async () => sh2.builtin("sed", ["-n", "1p", "somefile"]));
process.stdout.write([String(RESULT)].join(" ") + "\n");

await sh2._finish();
