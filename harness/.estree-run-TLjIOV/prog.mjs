import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/parse-error-escaped-dollar.sh", []);
sh2._setAllowlist(["/bin/sh","followed","by","a","non-identifier","character","should","be","literal","-c"]);
process.stdout.write("$-c\n");

await sh2._finish();
