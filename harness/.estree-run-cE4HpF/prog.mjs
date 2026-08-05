import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/tmp/tmp.0zau2RIi75/t4.sh", []);
sh2._setAllowlist(["quoted","x"]);
sh2.unsupported("echo \"quoted $x\"");

await sh2._finish();
