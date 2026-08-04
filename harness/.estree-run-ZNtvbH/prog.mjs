import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/qx-var-builtin-sed.sh", []);
sh2._setAllowlist(["/bin/sh","Check_qx:","generated","qx","var","where","contains","builtin","sed","all_interfaces","-n","s/.","//p","/dev/null"]);
let all_interfaces = "";
all_interfaces = await sh2.capture(async () => await sh2.redirect(async () => sh2.builtin("sed", ["-n", "s/.*//p"]), [{fd: 0, mode: "r", target: "/dev/null"}]));
process.stdout.write([String(all_interfaces)].join(" ") + "\n");

await sh2._finish();
