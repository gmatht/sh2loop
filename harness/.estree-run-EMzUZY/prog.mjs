import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("sh2perl/examples/063_12_complex_eval.sh", []);
sh2._setAllowlist(["/bin/bash","12.","Complex","with","nested","expansions","result","var:-0","+","array","index:-0",":-0","Eval","result:"]);
sh2.builtin("eval", [`result=$(( \${var:-0} + \${array[\${index:-0}]:-0} ))`]);
process.stdout.write([String(`Eval result: ${sh2.getVar("result")}`)].join(" ") + "\n");

await sh2._finish();
