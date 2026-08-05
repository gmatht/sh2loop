import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/arithmetic-equality.sh", []);
sh2._setAllowlist(["/bin/sh","Regression","test:","inside","...","arithmetic","must","be","handled.","The","Equality","token","recognized","in","expressions.","n","5","if","then","equal","fi","s","n:-"]);
sh2.setVar("n", "5");
if (sh2.builtin("let", ["$n == 5"])) { process.stdout.write("equal\n"); } else { sh2.lastExit = 0; }
process.stdout.write(`${"n"}=[${sh2.param(":-", "n", "")}]
`);

await sh2._finish();
