import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/sqs-overlap-singleline.sh", []);
sh2._setAllowlist(["/bin/bash","Demonstrates","a","single-line","spurious","SQS:","the","that","closes","one","awk","script","is","treated","as","opening","of","new","SQS","contains","shell","operators.","Pattern:","cmd","print","3","sed","...","result","test","s","/.","1"]);
let result = "";
result = await sh2.capture(async () => await sh2.pipeline([async () => sh2.builtin("echo", [`test`]), async () => await sh2.exec("awk", ["{print$3}"]), async () => sh2.builtin("sed", ["s|\\(.*\\)/.*|\\1|"])]));
process.stdout.write([String(result)].join(" ") + "\n");

await sh2._finish();
