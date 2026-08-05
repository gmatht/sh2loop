import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/double-bracket-or-chained.sh", []);
sh2._setAllowlist(["Demonstrate","chained","...","with","operators","Parser","failed","with:","Unexpected","token:","Or","if","-d","/efi/Default","/boot/Default","then","found","fi","exit:"]);
if (sh2.test("-d /efi/Default"), ((sh2.lastExit === 0) ? true : (sh2.test("-d /boot/Default"), (sh2.lastExit === 0)))) { process.stdout.write("found\n"), (sh2.lastExit = 0), true; } else { sh2.lastExit = 0; }
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
