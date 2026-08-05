import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/007_cat_EOF.sh", []);
sh2._setAllowlist(["cat","EOF","alpha","beta","gamma","...","FISH","oyster","snapper","salmon","Fin.","That","is","all","folks.","exit:"]);
await sh2.redirect(async () => sh2.builtin("cat", []), [{fd: 0, mode: "heredoc", target: "alpha\nbeta\ngamma ...\n", interpolate: true}]);
await sh2.redirect(async () => sh2.builtin("cat", []), [{fd: 0, mode: "heredoc", target: "oyster\nsnapper\nsalmon\n", interpolate: true}]);
process.stdout.write("Fin. That is all folks.\n"), (sh2.lastExit = 0), true;
process.stdout.write([String(`exit: ${sh2.lastExit}`)].join(" ") + "\n");

await sh2._finish();
