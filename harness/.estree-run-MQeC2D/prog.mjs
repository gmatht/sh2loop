import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/test-escaped-parens-in-function.sh", []);
sh2._setAllowlist(["check_path","if","-h","1","-a","-d","-o","then","ok","fi"]);
sh2.functions.set("check_path", () => { if (sh2.test("\\(! -h \"$1\" -a -d \"$1\"\\) -o \\( -h \"$1\"\\)")) { process.stdout.write("ok\n"), (sh2.lastExit = 0), true; } else { sh2.lastExit = 0; } }), true;

await sh2._finish();
