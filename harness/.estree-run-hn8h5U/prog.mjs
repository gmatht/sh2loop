import { sh2 } from "/a/i/sh2loop/harness/sh2-namespace.mjs";
sh2._init("testdata/t73_fish_string_len.fish", []);
sh2._setAllowlist(["t73_fish_string_len:","fish","string","length","builtin","diagnostics:","program","prints","its","result","to","stdout","hello","s","abc"]);
process.stdout.write("5\n");
sh2.setVar("s", `abc`);
process.stdout.write(String(sh2.arrayLen("s")) + "\n");

await sh2._finish();
