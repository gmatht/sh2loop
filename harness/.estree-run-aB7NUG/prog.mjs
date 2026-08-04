import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("/nvme/ai/sh2loop/sh2perl/examples/051_primes.sh", []);
sh2._setAllowlist(["/bin/bash","Prime","Number","Generator","This","script","finds","the","first","1000","prime","numbers","If","parser","doesn","t","support","+","it","choke","on","this","easy","examples.","y+","2","z+","a","b","primes","@",":0:1","Function","to","check","if","number","is","is_prime","n","1","-lt","then","fi","-eq","0","sqrt_n","sqrt","bc","i","3","while","-le","do","done","Finding","100","numbers...","may","take","while...","count","candidate","primes+","Show","progress","every","10","Found","so","far...","First","found","Count:","10:",":0:10","Last","-10","generation","complete"]);
let count = 0;
let candidate = 0;
let i = 0;
let __fn_is_prime = (...__sh2_args) => sh2.callUndefined("is_prime", __sh2_args);
sh2.assign("y", "+=", "2");
sh2.setArrayAppend("z", ["a", "b"]);
sh2.assign("z", "+=", sh2.param("slice", "primes[@]", "0", "1"));
process.stdout.write("=== Prime Number Generator (first 1000 primes) ===\n");
(__fn_is_prime = () => { sh2.builtin("local", ["n=$1"]); if (!Number.isNaN(Number(sh2.getVar("n"))) && (Number(sh2.getVar("n")) < Number(2))) { sh2.return("1"); } else { sh2.lastExit = 0; } if (!Number.isNaN(Number(sh2.getVar("n"))) && (Number(sh2.getVar("n")) === Number(2))) { sh2.return("0"); } else { sh2.lastExit = 0; } if (((Number(sh2.getVar("n")) || 0) % 2) === 0) { sh2.return("1"); } else { sh2.lastExit = 0; } sh2.builtin("local", ["sqrt_n=", [String(Math.floor(Math.sqrt(Number(sh2.getVar("n")))))]]); (i = 3), (sh2.lastExit = 0), true; sh2.whileLoopSync(() => (!Number.isNaN(Number(i)) && !Number.isNaN(Number(sh2.getVar("sqrt_n")))) && (Number(i) <= Number(sh2.getVar("sqrt_n"))), () => { if (sh2.imod(Number(sh2.getVar("n")) || 0, i) === 0) { sh2.return("1"); } else { sh2.lastExit = 0; } i = i + 2; }); sh2.return("0"); }), sh2.functions.set("is_prime", __fn_is_prime), true;
process.stdout.write("Finding first 100 prime numbers...\n");
process.stdout.write("This may take a while...\n");
sh2.setArray("primes", ["2"]);
count = 1;
candidate = 3;
while (count < 100) { if (sh2.callDirect(__fn_is_prime, [candidate])) { sh2.setArrayAppend("primes", [`${candidate}`]); count = count + 1; if ((count % 10) === 0) { process.stdout.write([String(`Found ${count} primes so far...`)].join(" ") + "\n"); } else { sh2.lastExit = 0; } } else { sh2.lastExit = 0; } candidate = candidate + 2; }
process.stdout.write("\n");
process.stdout.write("First 1000 prime numbers found!\n");
process.stdout.write([String(`Count: ${sh2.param("slice", "#primes", "@", "")}`)].join(" ") + "\n");
process.stdout.write([String(`First 10: ${sh2.join(sh2.param("slice", "primes", "0", "10"))}`)].join(" ") + "\n");
process.stdout.write([String(`Last 10: ${sh2.join(sh2.param("slice", "primes", " -10", ""))}`)].join(" ") + "\n");
process.stdout.write("Prime number generation complete!\n");

await sh2._finish();
