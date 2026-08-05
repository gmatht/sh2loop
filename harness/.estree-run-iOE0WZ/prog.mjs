import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/000__07_find_path_commands.sh", []);
sh2._setAllowlist(["/bin/bash","find","with","backticks","PERL_MUST_NOT_CONTAIN","found_files","-name",".sh","-type","f","Found","shell","scripts:","and","script_name","0","script_dir","Script","name:","directory:"]);
let found_files = "";
found_files = await sh2.capture(async () => await sh2.exec("find", [".", "-name", `*.sh`, "-type", "f"]));
process.stdout.write("Found shell scripts:\n");
process.stdout.write([String(found_files)].join(" ") + "\n");

await sh2._finish();
