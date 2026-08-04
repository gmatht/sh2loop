import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/000__04d_system_utilities.sh", []);
sh2._setAllowlist(["/bin/bash","System","utilities","using","backticks","This","file","demonstrates","system","utility","commands","with","Utilities","date","-","use","fixed","format","to","avoid","timing","issues","PERL_MUST_NOT_CONTAIN","timestamp","+","H:","M:","S","formatted_date","Y-","m-","d","Timestamp:","Formatted","date:","time","a","simple","test","that","doesn","t","vary","much","time_result","2","1","s/...","//","Time","result:","though","it","produce","output","sleep_duration","Sleeping","for","seconds...","which","bash_path","bash","Bash","path:","yes","yes_result","Hello","-3","Yes","Complete"]);
let yes_result = "";
let formatted_date = "";
let sleep_duration = "";
process.stdout.write("=== System Utilities ===\n");
formatted_date = await sh2.capture(async () => await sh2.exec("date", ["+%Y-%m-%d"]));
process.stdout.write([String(`Formatted date: ${formatted_date}`)].join(" ") + "\n");
sleep_duration = "1";
process.stdout.write([String(`Sleeping for ${sleep_duration} seconds...`)].join(" ") + "\n");
await sh2.exec("sleep", [sleep_duration]);
yes_result = await sh2.capture(async () => await sh2.pipeline([async () => await sh2.exec("yes", [`Hello`]), async () => sh2.builtin("head", ["-3"])]));
process.stdout.write("Yes command result:\n");
process.stdout.write([String(yes_result)].join(" ") + "\n");
process.stdout.write("=== System Utilities Complete ===\n");

await sh2._finish();
