import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("sh2perl/examples/nested-subshell-paren.sh", []);
sh2._setAllowlist(["/bin/sh","Nested","subshells","with","file","descriptor","redirects","result","gzip","-cdfq","--","file1","4","-","3","5","/dev/null","/dev/fd/5"]);
let result = "";
result = await sh2.capture(async () => await sh2.pipeline([async () => await sh2.redirect(async () => await sh2.subshell(async () => { await sh2.redirect(async () => await sh2.exec("gzip", ["-cdfq", "--", sh2.getVar("file1")]), [{fd: 4, mode: "w", target: "-"}]); await sh2.redirect(async () => sh2.builtin("echo", [sh2.lastExit]), [{fd: 1, mode: "w", target: "&4"}]); }), [{fd: 3, mode: "w", target: "-"}, {fd: 5, mode: "r", target: "-"}, {fd: 0, mode: "r", target: "/dev/null"}]), async () => await sh2.redirect(async () => sh2.builtin("eval", [sh2.getVar("cmp"), "/dev/fd/5", "-"]), [{fd: 1, mode: "w", target: "&3"}])]));
process.stdout.write([String(result)].join(" ") + "\n");

await sh2._finish();
