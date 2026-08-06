import { sh2 } from "/a/i/sh2loop/harness/sh2-namespace.mjs";
sh2._init("testdata/t44_background.fish", []);
sh2._setAllowlist(["t44_background:","background","job","and","diagnostics:","program","prints","its","result","to","stdout","1","main"]);
sh2.background(async () => await sh2.exec("sleep", ["1"]));
await sh2.exec("wait", []);
process.stdout.write("main\n");

await sh2._finish();
