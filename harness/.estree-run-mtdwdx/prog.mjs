import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/test-bracket-unclosed.sh", []);
sh2._setAllowlist(["/bin/sh","Test","bracket","expressions","if","-f","file","-r","then","readable","fi"]);
if (sh2.test("-f \"$file\""), ((sh2.lastExit === 0) ? (sh2.test("-r \"$file\""), (sh2.lastExit === 0)) : false)) { process.stdout.write("readable\n"); } else { sh2.lastExit = 0; }

await sh2._finish();
