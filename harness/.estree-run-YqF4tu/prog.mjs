import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/parse-dollar-end-of-string.sh", []);
sh2._setAllowlist(["/bin/sh","Test:","trailing","at","end","of","string","Parser","must","handle","followed","by","end-of-quote","or","end-of-line","hello","world","dollar"]);
let dollar = "";
process.stdout.write("hello$\n");
process.stdout.write("world$\n");
dollar = "$";
process.stdout.write([String(dollar)].join(" ") + "\n");

await sh2._finish();
