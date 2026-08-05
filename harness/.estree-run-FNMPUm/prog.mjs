import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/subshell-heredoc-close.sh", []);
sh2._setAllowlist(["/bin/sh","Subshell","with","heredoc","followed","by","closing","paren","var","hello","cat","EOF","content","after","s","n"]);
sh2.setVar("var", "hello");
await sh2.subshell(async () => await sh2.redirect(async () => sh2.builtin("cat", []), [{fd: 0, mode: "heredoc", target: "content\n", interpolate: true}]));
sh2.builtin("eval", [sh2.getVar("var")]);
process.stdout.write(`var after eval=[${sh2.getVar("var")}]
`);

await sh2._finish();
