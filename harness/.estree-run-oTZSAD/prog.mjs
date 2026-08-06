import { sh2 } from "/home/llm/sh2loop/harness/sh2-namespace.mjs";
sh2._init("frontends/c-sh-go/testdata/t05_while.c", []);
sh2._setAllowlist(["include","stdio.h","int","main","void","i","0","while","3","w","d","n","+","1"]);
let i = 0;
i = 0;
while (i < 3) { process.stdout.write(`w${parseInt(i, 10) || 0}
`); sh2.assign("i", "+=", i + 1); }

await sh2._finish();
