import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/003_pipeline.sh", []);
sh2._setAllowlist(["/bin/bash","Pipeline","examples","ls",".txt","-l","cat","file.txt","-c","-nr","find","-name",".sh","xargs","function","-d","/","This","pipeline","will","use","line-by-line","processing:","a","b","hello","fall","back","to","buffered"]);
await sh2.pipeline([async () => await sh2.exec("ls", []), async () => sh2.builtin("grep", [`\\.txt$`]), async () => sh2.builtin("wc", ["-l"])]);
process.stdout.write("\n");
await sh2.pipeline([async () => sh2.builtin("cat", ["file.txt"]), async () => sh2.builtin("sort", []), async () => sh2.builtin("uniq", ["-c"]), async () => sh2.builtin("sort", ["-n", "-r"])]);
process.stdout.write("\n");
await sh2.pipeline([async () => await sh2.exec("find", [".", "-name", `*.sh`]), async () => await sh2.exec("xargs", ["grep", "-l", `function`]), async () => sh2.builtin("tr", ["-d", `\\\\/`])]);
process.stdout.write("\n");
await sh2.pipeline([async () => sh2.builtin("cat", ["file.txt"]), async () => sh2.builtin("tr", ["a", "b"]), async () => sh2.builtin("grep", ["hello"])]);
process.stdout.write("\n");
await sh2.pipeline([async () => sh2.builtin("cat", ["file.txt"]), async () => sh2.builtin("sort", []), async () => sh2.builtin("grep", ["hello"])]);

await sh2._finish();
