import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/parse-comment-in-dollar-paren.sh", []);
sh2._setAllowlist(["/bin/bash","TempDir","/tmp/test_deterministic_dir"]);
let TempDir = "";
TempDir = `/tmp/test_deterministic_dir`;
process.stdout.write([String(TempDir)].join(" ") + "\n");

await sh2._finish();
