import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("sh2perl/examples/escaped-paren-command-subst.sh", []);
sh2._setAllowlist(["/bin/bash","Minimal","reproduction","of","escaped","parentheses","in","...","substitution","Similar","to","get_next_oid","failure","now","fixed","x","foo","bar","/dev/null","s","n","x:-"]);
let x = "";
x = await sh2.capture(async () => sh2.builtin("grep", ["foo\\(bar", "/dev/null"]));
process.stdout.write(`${"x"}=[${(String(x) !== "") ? String(x) : ""}]
`);

await sh2._finish();
