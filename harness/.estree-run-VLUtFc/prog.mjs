import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/readlink_relative.sh", []);
sh2._setAllowlist(["/bin/bash","Test","readlink","with","relative","symlinks","-f","/usr/bin/corepack","Corepack","resolves","to:"]);
let relative = "";
relative = await sh2.capture(async () => await sh2.exec("readlink", ["-f", "/usr/bin/corepack"]));
process.stdout.write([String(`Corepack resolves to: ${relative}`)].join(" ") + "\n");

await sh2._finish();
