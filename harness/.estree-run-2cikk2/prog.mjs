import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/qx-sed-in-command-var.sh", []);
sh2._setAllowlist(["/bin/sh","Command","stored","in","variable","and","run","via","backticks/qx","containing","sed","check_qx","violation:","is","a","builtin","used","qx","var","result","-n","s/foo/bar/p","/dev/null"]);
let result = "";
result = await sh2.capture(async () => await sh2.redirect(async () => sh2.builtin("sed", ["-n", "s/foo/bar/p"]), [{fd: 0, mode: "r", target: "/dev/null"}]));
process.stdout.write([String(result)].join(" ") + "\n");

await sh2._finish();
