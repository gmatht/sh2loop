import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/qx-scalar-var-with-builtin.sh", []);
sh2._setAllowlist(["/bin/sh","Test:","Generated","Perl","should","use","@_qx_cmd","array","not","scalar","to","avoid","check_qx.pl","Pattern","2","qx","var","where","contains","builtin","result","sed","-n","1p","/some/file"]);
let result = "";
result = await sh2.capture(async () => sh2.builtin("sed", ["-n", "1p", "/some/file"]));
process.stdout.write([String(result)].join(" ") + "\n");

await sh2._finish();
