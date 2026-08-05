import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/heredoc-subshell-redirects.sh", []);
sh2._setAllowlist(["/bin/sh","Heredoc","inside","subshell","with","redirects","on","same","line","var","test","EOF","2","1","/dev/null","the","body","heredoc+subshell+redirect","ran","OK","n","s","var:-"]);
sh2.setVar("var", "test");
await sh2.redirect(async () => { await sh2.subshell(async () => sh2.builtin("eval", [sh2.getVar("var")])); }, [{fd: 0, mode: "heredoc", target: "the body\n", interpolate: true}, {fd: 2, mode: "w", target: "&1"}, {fd: 1, mode: "w", target: "/dev/null"}]);
process.stdout.write("heredoc+subshell+redirect ran OK\n");
process.stdout.write(`${"var"}=[${sh2.param(":-", "var", "")}]
`);

await sh2._finish();
