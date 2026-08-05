import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/chown-standalone.sh", []);
sh2._setAllowlist(["/bin/sh","chown","standalone","-","triggers","open3","with","builtin","root:root","/tmp/testfile","exit:"]);
process.stdout.write("chown root:root /tmp/testfile\n"), (sh2.lastExit = 0), true;
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
