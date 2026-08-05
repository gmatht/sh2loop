import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/array-assignment-variable-subscript.sh", []);
sh2._setAllowlist(["Array","assignment","with","variable","subscript","expansion","FilesystemOptions","a","b","c","2","i","-1"]);
sh2.setArray("FilesystemOptions", ["a", "b", "c"]);
process.stdout.write([String(sh2.arrayIndex("FilesystemOptions", "(2*$i)-1"))].join(" ") + "\n");

await sh2._finish();
