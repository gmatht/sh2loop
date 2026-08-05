import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/064_18_array_slicing_manipulation.sh", []);
sh2._setAllowlist(["/bin/bash","18.","Array","slicing","and","manipulation","numbers","1","2","3","4","5","6","7","8","9","10","middle","@",":3:4","Elements","4-7","first_half",":0:5","First","elements","last_half",":5","Last","Middle:","half:"]);
sh2.setArray("numbers", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]);
sh2.setArray("middle", ["${numbers[@]:3:4}"]);
sh2.setArray("first_half", ["${numbers[@]:0:5}"]);
sh2.setArray("last_half", ["${numbers[@]:5}"]);
process.stdout.write([String(`Middle: ${sh2.join(sh2.param("slice", "middle", "@", ""))}`)].join(" ") + "\n");
process.stdout.write([String(`First half: ${sh2.join(sh2.param("slice", "first_half", "@", ""))}`)].join(" ") + "\n");
process.stdout.write([String(`Last half: ${sh2.join(sh2.param("slice", "last_half", "@", ""))}`)].join(" ") + "\n");

await sh2._finish();
