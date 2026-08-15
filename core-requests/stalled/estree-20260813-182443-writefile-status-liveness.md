# estree: fs.writeFile status-liveness — drop the .then((r) => lastExit=0, true) when $? is dead

## NEED

The redirect/writeFile lowering (`cmd > file` → `await sh2.fs.writeFile(
path, data).then(r => (sh2.lastExit = 0, true)).catch(e => (…report…,
sh2.lastExit = 1, false))`) should **drop the `.then` status closure**
when the write's exit status is lastexit-dead — the game's
`echo … > /dev/webgl/call` / `> /dev/webgl/uniform/…` writes (88
`.then(` sites, ~25/frame in render_frame) never read `$?` after.

## WHY

Each write pays a promise + two closures + a registration on the
success path, and the render path alone issues ~25 such writes/frame
(uniforms, binds, call, swap). The `.then(r => (sh2.lastExit = 0,
true))` exists ONLY to record `$?` — when the write's status is dead
(the game checks nothing after these writes), it is pure overhead.
The `.catch` is different: it REPORTS the failure (stderr) — keep it
(only its `sh2.lastExit = 1` tail is status, droppable).

## MINIMAL-CORE-CHANGE

Extend the lastexit-deadness analysis (the same `lastexit_dead`
verdict request …-lastexit-test-liveness uses) to the
redirect/writeFile emission in estree.rs / shir.rs: when the write's
status is dead, emit

    await sh2.fs.writeFile(path, data)
      .catch(e => process.stderr.write("bash: " + path + ": " + (e.code === "EACCES" ? "Permission denied" : e.code) + "\n"));

(drop the `.then` closure and the catch's status write; keep the error
report so a failing device still surfaces visibly). When the status IS
live (`cmd > file; echo $?`), keep the current form byte-for-byte.

## FAILING-CASE

    echo swap > /dev/webgl/call
    echo hi > /dev/webgl/uniform/1f/uOverlay

currently emits two full `.then(...).catch(...)` chains (4 closures +
2 registrations) per frame; with dead statuses (nothing reads `$?`
after either write): two bare `await writeFile(...).catch(report)`.
Output bytes identical on success (the catch is error-only); corpus
gate (`./fail-estree`) judges — the risk is a script that reads `$?`
after a redirect, which the liveness scan must keep live.
