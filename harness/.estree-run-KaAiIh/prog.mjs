import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/064_07_complex_array_operations.sh", []);
sh2._setAllowlist(["/bin/bash","7.","Complex","array","operations","with","associative","arrays","-A","config","user","admin","host","localhost","port","8080","Sort","values","to","avoid","hash-order","non-determinism","between","bash","and","Perl","IFS","n","sorted","Config:","@"]);
sh2.builtin("declare", ["-A", "config"]);
sh2.setVar("config[\"user\"]", `admin`);
sh2.setVar("config[\"host\"]", `localhost`);
sh2.setVar("config[\"port\"]", `8080`);
{ sh2.setVar("IFS", "\n"); sh2.setArray("sorted", ["$(sort <<<\"${config[*]}\")"]); }
process.stdout.write([String(`Config: ${sh2.join(sh2.param("slice", "sorted", "@", ""))}`)].join(" ") + "\n");

await sh2._finish();
