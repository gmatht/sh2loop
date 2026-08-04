import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/parse-complex-sed-in-dollarparen.sh", []);
sh2._setAllowlist(["/bin/sh","Test","sed","with","escaped","parens","inside","...","in","double-quoted","string","x","foo","s","bar"]);
let x = "";
x = await sh2.capture(async () => await sh2.pipeline([async () => sh2.builtin("echo", ["foo"]), async () => sh2.builtin("sed", ["s|foo|bar|"])]));
process.stdout.write([String(x)].join(" ") + "\n");

await sh2._finish();
