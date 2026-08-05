import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/075_eval_complex.sh", []);
sh2._setAllowlist(["/bin/bash","Eval","with","substitution","inside","x","42","The","answer","is"]);
let x = 0;
x = 42;
sh2.builtin("eval", [`echo "The answer is ${x}"`]);

await sh2._finish();
