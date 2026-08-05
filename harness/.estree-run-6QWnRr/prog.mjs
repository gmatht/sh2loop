import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/tmp/tmp.0zau2RIi75/t2.sh", []);
sh2._setAllowlist(["x","5"]);
sh2.setVar("x", "5");
sh2.unsupported("echo $x");

await sh2._finish();
