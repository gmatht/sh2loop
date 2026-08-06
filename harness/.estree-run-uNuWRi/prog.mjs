import { sh2 } from "/home/llm/sh2loop/harness/sh2-namespace.mjs";
sh2._init("sh2perl/examples/double-paren-subshell.sh", []);
sh2._setAllowlist(["/bin/sh","used","for","nested","subshell","cmd1","cmd2","not","arithmetic","result","gzip","-cdfq","--","file1","4","-","3","/dev/null","/dev/fd/5"]);
let result = "";
result = await sh2.capture(async () => { await sh2.subshell(async () => await sh2.pipeline([async () => await sh2.redirect(async () => await sh2.subshell(async () => { await sh2.redirect(async () => await sh2.exec("gzip", ["-cdfq", "--", sh2.getVar("file1")]), [{fd: 4, mode: "w", target: "-"}]); await sh2.redirect(async () => sh2.builtin("echo", [sh2.split(sh2.lastExit)]), [{fd: 1, mode: "w", target: "&4"}]); }), [{fd: 3, mode: "w", target: "-"}, {fd: 0, mode: "r", target: "/dev/null"}]), async () => await sh2.redirect(async () => sh2.builtin("eval", ["cmp", "/dev/fd/5", "-"]), [{fd: 1, mode: "w", target: "&3"}])])); });
process.stdout.write(String(result) + "\n");

await sh2._finish();
