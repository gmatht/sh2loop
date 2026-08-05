import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/100_pipeline_failure_basic.sh", []);
sh2._setAllowlist(["/bin/bash","Pipeline","failure","demo:","basic","pipe","returns","empty","in","pure","Perl","mode","File","list:","ls","-1","/tmp","2","/dev/null","-3","---","Count:","-l","done"]);
process.stdout.write("File list:\n");
await sh2.pipeline([async () => await sh2.redirect(async () => await sh2.exec("ls", ["-1", "/tmp"]), [{fd: 2, mode: "w", target: "/dev/null"}]), async () => sh2.builtin("head", ["-3"])]);
process.stdout.write("---\n");
process.stdout.write("Count:\n");
await sh2.pipeline([async () => await sh2.redirect(async () => await sh2.exec("ls", ["/tmp"]), [{fd: 2, mode: "w", target: "/dev/null"}]), async () => sh2.builtin("wc", ["-l"])]);
process.stdout.write("done\n");

await sh2._finish();
