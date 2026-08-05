import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/arithmetic-var-ref.sh", []);
sh2._setAllowlist(["/bin/bash","Minimal","reproduction","of","arithmetic","expression","with","variable","references","Similar","to","git-submodule","/","growpart","failures","var","+","1"]);
process.stdout.write([String((Number(sh2.getVar("var")) || 0) + 1)].join(" ") + "\n");

await sh2._finish();
