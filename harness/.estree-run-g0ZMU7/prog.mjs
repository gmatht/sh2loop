import { sh2 } from "/nvme/ai/sh2loop/harness/sh2-namespace.mjs";
sh2._init("sh2perl/examples/tty-cmdsub.sh", []);
sh2._setAllowlist(["/usr/bin/env","bash","tty-cmdsub.sh","-------------","Minimal","self-contained","demo","of","the","GNU","coreutils","tty","command.","This","script","is","designed","to","be","safe","no","rm","-rf","destructive","ops","It","used","as","a","test","case","for","shell-to-Perl","translator.","Each","section","prints","debug-like","output","show","what","returns.","Options","deliberately","excluded:","--version","--help","and","anything","that","goes","exclusively","stderr","handled","but","not","focus","-u","treat","variables","an","error","--------------------------------------------------------------------------","Helper:","run","capture","its","stdout","code.","label","1","tmp_stdout","tmp_stderr","mktemp","/tmp/tty_demo_stdout_XXXXXX","/tmp/tty_demo_stderr_XXXXXX","Run","saving","both","streams.","@","2","ec","so","cat","se","-f","---","cmd","exitcode:","if","-n","then","else","empty","fi","Determine","terminal","device","readable","by","current","process.","We","use","/dev/pts/2","/dev/pts/3","/dev/pts/4","owned","user","ai","on","this","system","Fall","back","first","pts.","TTY_DEV","dev","in","do","-r","done","-z","Last","resort:","pick","any","pts","or","/dev/pts/","Using","device:","TTY_DEV:-NONE","1.","Default","with","real","stdin","redirected","from","Expect:","name","code","0","SECTION","1:","default","01-default-terminal","skipped","available","2.","/dev/null","2:","02-not-a-tty","3.","piped","input","3:","03-pipe-notty","-c","dummy","4.","-s","silent","4:","04-silent-terminal","5.","5:","05-silent-notty","6.","6:","06-silent-pipe","7.","--silent","long","form","7:","07-long-silent","8.","--quiet","alternative","8:","08-long-quiet","9.","9:","09-long-silent-notty","10.","10:","10-long-quiet-notty","11.","without","redirect","inherits","The","itself","runs","whatever","caller","provided.","as-is.","11:","inheriting","11-inherited","12.","12:","12-inherited-silent","13.","repeated","flag","should","harmless","13:","13-double-silent","Summary","All","sections","completed."]);
let TTY_DEV = "";
let dev = "";
sh2.builtin("set", ["-u"]);
sh2.functions.set("capture", async () => { sh2.builtin("local", ["label=", sh2.positional[0] ?? ""]); sh2.builtin("shift", []); sh2.builtin("local", ["tmp_stdout", "tmp_stderr"]); sh2.setVar("tmp_stdout", await sh2.capture(async () => sh2.builtin("mktemp", ["/tmp/tty_demo_stdout_XXXXXX"]))); sh2.setVar("tmp_stderr", await sh2.capture(async () => sh2.builtin("mktemp", ["/tmp/tty_demo_stderr_XXXXXX"]))); await sh2.redirect(async () => await sh2.exec(sh2.positional.join(" "), []), [{fd: 1, mode: "w", target: sh2.getVar("tmp_stdout")}, {fd: 2, mode: "w", target: sh2.getVar("tmp_stderr")}]); sh2.builtin("local", ["ec=", sh2.lastExit]); sh2.builtin("local", ["so"]); sh2.setVar("so", await sh2.capture(async () => sh2.builtin("cat", [sh2.getVar("tmp_stdout")]))); sh2.builtin("local", ["se"]); sh2.setVar("se", await sh2.capture(async () => sh2.builtin("cat", [sh2.getVar("tmp_stderr")]))); await Promise.all([sh2.fs.unlink(sh2.getVar("tmp_stdout")).then(() => 0, (e) => (e && (e.code === "ENOENT")) ? 0 : 1), sh2.fs.unlink(sh2.getVar("tmp_stderr")).then(() => 0, (e) => (e && (e.code === "ENOENT")) ? 0 : 1)]).then((s) => ((sh2.lastExit = !s.includes(1) ? 0 : 1), (sh2.lastExit === 0))); sh2.builtin("echo", [`--- [${sh2.param("", "label")}] ---`]); sh2.builtin("echo", [`  cmd     : ${sh2.positional.join(" ")}`]); sh2.builtin("echo", [`  exitcode: ${sh2.param("", "ec")}`]); if (String(sh2.getVar("so")) !== "") { sh2.builtin("echo", [`  stdout  : ${sh2.param("", "so")}`]); } else { sh2.builtin("echo", [`  stdout  : (empty)`]); } if (String(sh2.getVar("se")) !== "") { sh2.builtin("echo", [`  stderr  : ${sh2.param("", "se")}`]); } else { sh2.lastExit = 0; } sh2.builtin("echo", [``]); sh2.return(sh2.getVar("ec")); }), true;
TTY_DEV = ``;
(sh2._g = await sh2.forLoop(["/dev/pts/2", "/dev/pts/3", "/dev/pts/4"], async (dev) => { if (await sh2.fs.lstat(dev).then((s) => (s.mode & 292) !== 0, () => false)) { TTY_DEV = dev; sh2.break(); } else { sh2.lastExit = 0; } })), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
if (String(TTY_DEV) === "") { await sh2.forLoop(["\u0001SH2GLOB\u0001/dev/pts/*"], async (dev) => { if (await sh2.fs.lstat(dev).then((s) => (s.mode & 292) !== 0, () => false)) { TTY_DEV = dev; sh2.break(); } else { sh2.lastExit = 0; } }); } else { sh2.lastExit = 0; }
process.stdout.write([String(`Using terminal device: ${(String(TTY_DEV) !== "") ? String(TTY_DEV) : "NONE"}`)].join(" ") + "\n"), (sh2.lastExit = 0), true;
process.stdout.write("\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 1: tty (default) — with a real terminal\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
if (String(TTY_DEV) !== "") { await sh2.redirect(async () => await sh2.exec("capture", [`01-default-terminal`, "tty"]), [{fd: 0, mode: "r", target: TTY_DEV}]); } else { process.stdout.write("  (skipped — no terminal device available)\n"), (sh2.lastExit = 0), true; process.stdout.write("\n"), (sh2.lastExit = 0), true; }
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 2: tty (default) — stdin from /dev/null\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.redirect(async () => await sh2.exec("capture", [`02-not-a-tty`, "tty"]), [{fd: 0, mode: "r", target: "/dev/null"}])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 3: tty (default) — piped input\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.exec("capture", [`03-pipe-notty`, "bash", "-c", "echo \"dummy\" | tty"])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 4: tty -s — with a real terminal (silent)\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
if (String(TTY_DEV) !== "") { await sh2.redirect(async () => await sh2.exec("capture", [`04-silent-terminal`, "tty", "-s"]), [{fd: 0, mode: "r", target: TTY_DEV}]); } else { process.stdout.write("  (skipped — no terminal device available)\n"), (sh2.lastExit = 0), true; process.stdout.write("\n"), (sh2.lastExit = 0), true; }
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 5: tty -s — stdin from /dev/null (silent, not a tty)\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.redirect(async () => await sh2.exec("capture", [`05-silent-notty`, "tty", "-s"]), [{fd: 0, mode: "r", target: "/dev/null"}])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 6: tty -s — piped input (silent, not a tty)\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.exec("capture", [`06-silent-pipe`, "bash", "-c", "echo \"dummy\" | tty -s"])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 7: tty --silent — long form, with a real terminal\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
if (String(TTY_DEV) !== "") { await sh2.redirect(async () => await sh2.exec("capture", [`07-long-silent`, "tty", "--silent"]), [{fd: 0, mode: "r", target: TTY_DEV}]); } else { process.stdout.write("  (skipped — no terminal device available)\n"), (sh2.lastExit = 0), true; process.stdout.write("\n"), (sh2.lastExit = 0), true; }
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 8: tty --quiet — long form, with a real terminal\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
if (String(TTY_DEV) !== "") { await sh2.redirect(async () => await sh2.exec("capture", [`08-long-quiet`, "tty", "--quiet"]), [{fd: 0, mode: "r", target: TTY_DEV}]); } else { process.stdout.write("  (skipped — no terminal device available)\n"), (sh2.lastExit = 0), true; process.stdout.write("\n"), (sh2.lastExit = 0), true; }
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 9: tty --silent — stdin from /dev/null (not a tty)\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.redirect(async () => await sh2.exec("capture", [`09-long-silent-notty`, "tty", "--silent"]), [{fd: 0, mode: "r", target: "/dev/null"}])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 10: tty --quiet — stdin from /dev/null (not a tty)\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.redirect(async () => await sh2.exec("capture", [`10-long-quiet-notty`, "tty", "--quiet"]), [{fd: 0, mode: "r", target: "/dev/null"}])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 11: tty (default) — inheriting stdin from the script\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.exec("capture", [`11-inherited`, "tty"])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 12: tty -s — inheriting stdin from the script\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
(sh2._g = await sh2.exec("capture", [`12-inherited-silent`, "tty", "-s"])), ((sh2.errexit && !sh2._g) ? process.exit(0) : sh2._g);
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
process.stdout.write(" SECTION 13: tty -s -s — repeated silent flag\n"), (sh2.lastExit = 0), true;
process.stdout.write("============================================================\n"), (sh2.lastExit = 0), true;
if (String(TTY_DEV) !== "") { await sh2.redirect(async () => await sh2.exec("capture", [`13-double-silent`, "tty", "-s", "-s"]), [{fd: 0, mode: "r", target: TTY_DEV}]); } else { process.stdout.write("  (skipped — no terminal device available)\n"), (sh2.lastExit = 0), true; process.stdout.write("\n"), (sh2.lastExit = 0), true; }
process.stdout.write("\n"), (sh2.lastExit = 0), true;
process.stdout.write("All tty demo sections completed.\n"), (sh2.lastExit = 0), true;

await sh2._finish();
