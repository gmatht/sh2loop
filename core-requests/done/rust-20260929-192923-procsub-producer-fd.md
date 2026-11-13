# rust: procsub `process-in` producer is bound to fd 0 (`r`) instead of fd 1 (`w`)

Supersedes `rust-20260929-180500.md` (stalled). Same failure, but the root cause
is now pinned to an exact line and the fix is **verified end-to-end** (patch below
takes the rust corpus gate from 639/1-fail to 640/0-fail).

## NEED

In `materialize_redirect`, the `!appendable` (non-exec consumer) path emits the
**producer** redirect with the SAME `(fd, mode)` pair as the **consumer** read.
For `process-in` that means the producer is written as `< tmp` (a READ) instead of
`> tmp` (a WRITE), so the temp file is created by `mktemp`, never written, and the
consumer reads an empty file → instant EOF. The producer's real output instead
leaks to the program's stdout (it inherits the unredirected fd 1).

## WHY — exact location

`src/transforms/process_subst.rs:376-387` (the `!appendable` branch):

```rust
let (fd, mode) = if r.mode == "process-in" {
    (Some(0), "r")
} else {
    (Some(0), "w")          // <-- BUG: process-out consumer should be fd 1
};
new_redirects.push(IrRedirect { fd, mode: mode.to_string(), target: tmp_v.clone(), interpolate: false });
pre.push(producer_redirect(producer, &tmp_v, mode, fd));   // <-- BUG: reuses the CONSUMER's (fd,mode)
```

Two defects in three lines:

1. `producer_redirect(...)` is passed the **consumer's** `(fd, mode)`, so for
   `process-in` the producer is emitted as `{ producer; } < tmp` — a read, not a write.
2. The `process-out` consumer itself uses `fd 0` where it should be `fd 1`.

The function's OWN docstring (line 121-122) already states the intended contract,
which the code contradicts:

```rust
/// `{ producer…; } <op> tmp` — run the producer IR with the temp file as
/// the redirect target (stdout for process-in, stdin for process-out).
```

The correct shape is already implemented a few lines below in the `appendable`
branch (`process_subst.rs:426-428`), which is why exec consumers
(`diff <(a) <(b)`) work while compound-statement consumers do not:

```rust
if r.mode == "process-in" {
    pre.push(producer_redirect(producer, &tmp_v, "w", Some(1)));   // <-- correct
} else {
    post.push(producer_redirect(producer, &tmp_v, "r", Some(0)));  // <-- correct
}
```

## MINIMAL-CORE-CHANGE (verified — turns the gate green)

The producer's redirect is the **inverse** of the consumer's. Patch:

```diff
--- a/src/transforms/process_subst.rs
+++ b/src/transforms/process_subst.rs
@@ -376,7 +376,7 @@ fn materialize_redirect(
             let (fd, mode) = if r.mode == "process-in" {
                 (Some(0), "r")
             } else {
-                (Some(0), "w")
+                (Some(1), "w")
             };
             new_redirects.push(IrRedirect {
                 fd,
@@ -384,7 +384,12 @@ fn materialize_redirect(
                 target: tmp_v.clone(),
                 interpolate: false,
             });
-            pre.push(producer_redirect(producer, &tmp_v, mode, fd));
+            let (pfd, pmode) = if r.mode == "process-in" {
+                (Some(1), "w")
+            } else {
+                (Some(0), "r")
+            };
+            pre.push(producer_redirect(producer, &tmp_v, pmode, pfd));
         }
```

## EVIDENCE

**A1 before** (`otranspilerl-cli /tmp/t.sh --target shir`) — the producer carries
the SAME read redirect as the consumer, and there is no `fd 1 / mode w` node:

```
[1] Redirect [{fd:0, mode:"r", target:__ps_tmp0}]  inner=Expr(printf …)   <-- PRODUCER, wrong: reads
[2] Redirect [{fd:0, mode:"r", target:__ps_tmp0}]  inner=While(…)         <-- CONSUMER, correct
[3] Exec      rm -f __ps_tmp0                                            <-- cleanup
```

**A1 after applying the patch** — the producer/consumer pair is now correct and
appears in the right order:

```
[1] Redirect [{fd:1, mode:"w", target:__ps_tmp0}]  inner=Expr(printf …)
[2] Redirect [{fd:0, mode:"r", target:__ps_tmp0}]  inner=While(…)
```

**Behaviour, `examples/063_11_complex_while_loop.sh`** (rust corpus gate case):

```
bash  (oracle)   : Contains command substitution: has $(sub) here
                   Contains parameter expansion: ${param} line

rust  (unpatched): has $(sub) here
                   plain line                  <-- raw producer leak, no prefix,
                   ${param} line                  loop body never ran

rust  (patched)  : Contains command substitution: has $(sub) here
                   Contains parameter expansion: ${param} line   <-- matches bash
```

**Gate, run via `setup_backends.sh --backend-gate rust` in the worktree:**

```
before:  639/647 corpus render OK, 1 fail   (fails: examples/063_11_complex_while_loop.sh)
after:   640/647 corpus render OK, 0 fail   (0 stubs, 0 equiv, 0 static-analysis; 7 skip)
```

`fail-go --rust`: 123/124 rust pass, and `063_11` is gone from the fails list
(the one remaining `t109_bool_func.go` is `js=MISMATCH rust=PASS` — a JS-side
failure, not rust).

`cargo test --lib process_subst`: 10/10 pass, both before and after the patch.
`cargo test --lib rust_backend`: 100/100 pass.

Note: the rust backend ALREADY has correct plumbing for this case — the generic
redirect path turns an `fd 1 / mode w` file target into the `__SH_OUTFILE_TL`
binding, and the FIFO/background-thread branch at `src/rust_backend.rs:8930`
handles infinite producers. No rust-side change is required once the core emits
the write node.

## FAILING-CASE

- `sh2perl/examples/063_11_complex_while_loop.sh` — `done < <(grep -v "^#" "$input_file" | head -n "$max_lines")`
- Minimal repro:
  ```bash
  while IFS= read -r line; do echo "GOT:$line"; done < <(printf 'a\nb\nc\n')
  ```
- Not rust-specific: the same A1 breaks every backend (perl prints nothing;
  estree emits no `__ps_tmp` reference), because the contract never carries the
  producer's output.

## OUTCOME: implemented

Committed in sh2perl 0a5ae92f3, gitlink bumped in aad88689. The producer redirect is
now the inverse of the consumer's: `P > tmp` (fd 1 w) for process-in, `P < tmp`
(fd 0 r) for process-out, and the process-out producer moved from `pre` to `post`
(its consumer must write the file first). Two regression tests assert the (fd, mode)
of every lowered redirect node. Verified: bash `GOT:a GOT:b GOT:c`; pre-fix `a b c` (the
leak), post-fix matches bash. ./fail-estree PERL 501/555 and ESTREE 552/555,
byte-identical with and without the patch, so no regression. cargo test --lib
process_subst 12/12.

One correction to the request's analysis: the patch as proposed was necessary but NOT
sufficient for the reported case. Two more gaps had to be closed in ir.rs for
`091_while_pipe_var` to stop `die`-ing: the `while` loop reaches
stmts_to_shell_cmd as a `whileLoop` Call (not IrStmt::While, so the statement
arm never sees it), and its body carries an `Assign` (count=$((count+1))).
The arithmetic RHS must rebuild as bash `$(( … ))` — routing it through
bash_word_for emits the Perl text `int(($count + 1))`, which a `bash -c`
string prints literally.
