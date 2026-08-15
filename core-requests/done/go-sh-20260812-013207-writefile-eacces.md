# go-sh: native echo-redirect writeFile aborts the whole program on EACCES (bash reports and continues)

## NEED
`try_native_echo_redirect`'s emitted `await sh2.fs.writeFile(...)` /
`appendFile(...)` (shir.rs ~11552, used by the `IrStmt::Redirect`
arm ~13247) must tolerate write failures the way bash does: report
`bash: <target>: Permission denied`, set status 1, and let the
program CONTINUE — not throw an uncaught rejection that kills the
whole module.

## WHY
The go-sh frontend lowers `os.WriteFile("/tmp/f", []byte("data\n"),
0o644)` to the standard A1 shape
`Redirect { inner: [exec(echo, ["data"])], redirects: [{fd:1, mode:"w", target:"/tmp/f"}] }`
— byte-identical to what the core's own shell frontend emits for
`echo data > /tmp/f`. The core's ESTree lowering takes the native
fast path (`try_native_echo_redirect` qualifies: one spec, fd 1,
mode w, literal target, literal args) and emits:

    (await sh2.fs.writeFile('/tmp/f', 'data' + '\n'), sh2.lastExit = 0, true)

with NO error handling. `sh2.fs` is `node:fs/promises` — on EACCES
the rejection is uncaught and the entire program dies with empty
stdout, while bash prints `bash: /tmp/f: Permission denied`, sets
status 1, and runs the NEXT command (`fmt.Println("wrote")` still
outputs). The runtime's OWN generic redirect path (`sh2.redirect` /
`_applyRedirectSpecs`) handles exactly this case correctly (emitErr
+ `lastExit = 1` + return false), so only the native shortcut is
divergent. Triggered in the go-sh gate by a stale root-owned
`/tmp/f` (0644) with the worker running as uid 1008.

## MINIMAL-CORE-CHANGE
In the `try_native_echo_redirect` emitter: wrap the writeFile (and
appendFile) call in a try/catch that mirrors `_applyRedirectSpecs`'s
write-mode error path:

    try { await sh2.fs.writeFile(t, content) }
    catch (e) { process.stderr.write('bash: ' + t + ': ' + (e.code === 'EACCES' ? 'Permission denied' : e.code) + '\n'); sh2.lastExit = 1; }

replacing the trailing `sh2.lastExit = 0` with the conditional
status, keeping the sequence's final `true`/`false` consistent with
the command's success (a failed redirect → status 1, falsy tail so
`&&`/`||`/errexit semantics hold).

## FAILING-CASE
frontends/go-sh/testdata/t32_redirect.go (with `/tmp/f` existing as
root-owned 0644 and the runner uid non-root):

    os.WriteFile("/tmp/f", []byte("data\n"), 0o644)
    fmt.Println("wrote")

Native Go stdout: `wrote` (the WriteFile error is ignored, like bash
continues). Transpiled (estree-runner): uncaught
`EACCES: permission denied, open '/tmp/f'` — empty stdout, gate DIFF.

## OUTCOME: implemented: try_native_echo_redirect now emits `sh2.fs.writeFile/appendFile(t, c).then(r => (sh2.lastExit = 0, true)).catch(e => (process.stderr.write('bash: ' + t + ': ' + (e.code === 'EACCES' ? 'Permission denied' : e.code) + '\n'), sh2.lastExit = 1, false))` — bash-style report-and-continue (verified: unwritable target prints `bash: f: EISDIR`, the program continues; corpus 521/521).
