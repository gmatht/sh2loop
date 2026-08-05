import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/tmp/tmp.0zau2RIi75/t1.sh", []);
sh2._setAllowlist(["hello"]);
sh2.unsupported("echo hello");

await sh2._finish();
