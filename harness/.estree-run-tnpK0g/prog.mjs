import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/escaped-singlequote-in-doublequote.sh", []);
sh2._setAllowlist(["/bin/sh","Escaped","single-quote","inside","double-quoted","string","pkg","dummy","conffile","test","x","dpkg-query","-W","-f","Conffiles","sed","-n","-e","s/","obsolete","//","s/.","p","result","s","n","pkg:-","conffile:-"]);
let x = "";
let pkg = "";
let conffile = "";
pkg = "dummy";
conffile = "test";
x = await sh2.capture(async () => await sh2.pipeline([async () => await sh2.exec("dpkg-query", ["-W", `-f=${sh2.param("", "Conffiles")}`, pkg]), async () => sh2.builtin("sed", ["-n", "-e", `\\' ${conffile} ' { s/ obsolete$//; s/.* //; p }`])]));
process.stdout.write(`result=[${x}]
`);
process.stdout.write(`${"pkg"}=[${(String(pkg) !== "") ? String(pkg) : ""}]
`);
process.stdout.write(`${"conffile"}=[${(String(conffile) !== "") ? String(conffile) : ""}]
`);

await sh2._finish();
