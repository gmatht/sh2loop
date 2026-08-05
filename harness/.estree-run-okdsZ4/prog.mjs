import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/063_16_complex_test_expressions.sh", []);
sh2._setAllowlist(["/bin/bash","16.","Complex","test","expressions","with","multiple","operators","if","-n","var","-a","-f","file","-o","-d","dir","-l","-gt","10","then","passed","fi"]);
if (sh2.test(" -n \"$var\" -a -f \"$file\" -o -d \"$dir\""), ((sh2.lastExit === 0) ? (sh2.test("\"$(wc -l < \"$file\")\" -gt 10"), (sh2.lastExit === 0)) : false)) { process.stdout.write("Complex test passed\n"); } else { sh2.lastExit = 0; }

await sh2._finish();
