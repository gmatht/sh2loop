import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/parse-complex-pipeline-quotes.sh", []);
sh2._setAllowlist(["/bin/bash","Multiple","single-quoted","strings","in","a","pipeline.","The","interaction","between","quotes","different","parts","of","pipeline","previously","caused","the","logos","tokenizer","to","stop.","result","data","sed","s/foo/bar/g","awk","print","2"]);
let result = "";
result = await sh2.capture(async () => await sh2.pipeline([async () => sh2.builtin("echo", [`data`]), async () => sh2.builtin("sed", ["s/foo/bar/g"]), async () => await sh2.exec("awk", ["{print $2}"])]));
process.stdout.write([String(result)].join(" ") + "\n");

await sh2._finish();
