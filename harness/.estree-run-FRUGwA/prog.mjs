import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/variable-apostrophe-concat.sh", []);
sh2._setAllowlist(["/bin/sh","Variable","concatenated","with","single-quoted","string","x","hello","y","world","s","n","x:-"]);
let y = "";
let x = "";
x = "hello";
y = `${x}world`;
process.stdout.write([String(y)].join(" ") + "\n");
process.stdout.write(`${"x"}=[${(String(x) !== "") ? String(x) : ""}]
`);

await sh2._finish();
