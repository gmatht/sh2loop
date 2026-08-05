import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/101_pipeline_failure_grep.sh", []);
sh2._setAllowlist(["/bin/bash","Pipeline","failure:","via","pipe","returns","empty","Grep","test:","alpha","beta","gamma","---","-o","done"]);
process.stdout.write("Grep test:\n");
sh2.grepText("alpha beta gamma" + "\n", ["beta"], false);
process.stdout.write("---\n");
sh2.grepText("alpha beta gamma" + "\n", ["-o", "beta"], false);
process.stdout.write("done\n");

await sh2._finish();
