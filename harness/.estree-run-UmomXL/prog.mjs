import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/variable-assignment-concatenated-string.sh", []);
sh2._setAllowlist(["Demonstrate","variable","assignment","with","concatenated","quoted","string","e.g.","var","or","dest_root","emmccheck","p3"]);
let dest_root = "";
dest_root = `${sh2.getVar("emmccheck")}p3`;
process.stdout.write([String(dest_root)].join(" ") + "\n");

await sh2._finish();
