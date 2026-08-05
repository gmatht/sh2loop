import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/parse-heredoc-eof-unexpected.sh", []);
sh2._setAllowlist(["/bin/sh","Heredoc","with","parameter","expansions","inside","VAR","hello","VAR2","world","if","then","cat","EOF","more","text","fi","s","n","VAR:-","VAR2:-"]);
sh2.setVar("VAR", "hello");
sh2.setVar("VAR2", "world");
if ((sh2.lastExit = 0), true) { await sh2.redirect(async () => sh2.builtin("cat", []), [{fd: 0, mode: "heredoc", target: "${VAR} more ${VAR2} text\n", interpolate: true}]); } else { sh2.lastExit = 0; }
process.stdout.write(`${"VAR"}=[${sh2.param(":-", "VAR", "")}]
`);
process.stdout.write(`${"VAR2"}=[${sh2.param(":-", "VAR2", "")}]
`);

await sh2._finish();
