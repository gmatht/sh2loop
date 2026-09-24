# C backend / process substitution: the FIFO cleanup `rm` runs BEFORE `$?` is read, clobbering it

**Status:** diagnosed to the exact transform line, not fixed — needs a shared-core mechanism (see Root cause). Affects `cmp`/`diff`-style scripts that use
process substitution and then read `$?`.

## Symptom

`070_cmp_basic.sh` differs from bash by exactly one line:

    bash:  bc -s exit: 1     # cmp -s <(echo b) <(echo c) -> the files differ
    C:     bc -s exit: 0     # reads the CLEANUP rm's status instead

The prior line (`aa -s exit: 0`, equal files) agrees, so the render of
process substitution itself is fine — it is the *ordering* of the generated
cleanup.

## Cause

For `cmp -s <(echo b) <(echo c)` the renderer emits a block that hoists the
two FIFOs and then runs several shell sites:

    {
        __ps_tmp2 = strdup((char*)(_cap_27()));   /* mktemp + echo b > FIFO */
        _sh_site_28();
        __ps_tmp3 = strdup((char*)(_cap_29()));   /* mktemp + echo c > FIFO */
        _sh_site_30();
        _sh_site_31();                            /* cmp -s TMP2 TMP3  <-- the real command */
        _sh_site_32();                            /* rm -f TMP2 TMP3   <-- the CLEANUP */
    }
    long long _q16 = _sh_rc;
    printf("bc -s exit: %d\n", _q16), _sh_rc = 0;

`_sh_rc` after the block is `_sh_site_32`'s status — the `rm -f`, which
succeeds (0) — so `$?` reads the cleanup instead of `cmp`. In bash the
cleanup is not part of the user-visible sequence before the `echo`, so
`$?` is cmp's 1.

I verified the site identities by dumping each helper's command words:
site_31 = `cmp -s TMP2 TMP3`, site_32 = `rm -f TMP2 TMP3`.

## Why it matters beyond this one test

Any script that uses process substitution and then reads `$?`/`&&`/`||` —
a common `cmp`/`diff`/`comm` idiom — will read the wrong status. The bug is
in how the process-substitution transform sequences its teardown relative to
the status that bash publishes.

## Reproduction

    ./setup_backends.sh --backend-gate c        # 070_cmp_basic.sh fails
    cd /tmp && bash /home/llm/sh2loop/sh2perl/examples/070_cmp_basic.sh > b.out
    # render + compile the same file for C, run with argv0 matched for $0:
    # bash -c 'exec -a "$0" "$1"' <script> <bin> > c.out
    diff b.out c.out      # -> "bc -s exit: 1" vs "0"

## Root cause (located)

`sh2perl/src/transforms/process_subst.rs` sequences the teardown AFTER the
user's command, and the transform's own comments name the problem — twice:

    // process-out present: the producer-read runs regardless of
    // the exec's status — plain sequence, rm last (status caveat).
    seq.push(rm);

and, in the call-form path:

    // process-out present: the producer-read must run regardless of
    // the exec's status (it CONSUMES the file), so a plain sequence
    // stays; the trailing rm is the last status (accepted caveat).
    out.push(rm);

So the rm is deliberately last and its status is knowingly published. The
process-IN path avoids this by wrapping in `and(Arrow(seq), Arrow([rm]))`, so
the enclosing status dispatch still sees the exec's code — but the
process-OUT path cannot use `and()` (the producer-read must run regardless of
the exec's status), so it takes the plain-sequence branch and leaks the rm's
status.

`070_cmp_basic.sh` uses `cmp -s <(echo b) <(echo c)`: two process-IN specs,
but the transform takes its `has_post` branch, hence the leak.

## Why it needs an IR mechanism, not a local patch

The obvious fix is to save/restore the status around the teardown:

    { int _rcs = _sh_rc; rm -f ...; _sh_rc = _rcs; }

but a RENDERER cannot do this safely: it cannot distinguish a
transform-generated cleanup `rm` from a user-written `rm -f`, and suppressing
a user's own status would be a regression. `Subshell` does not help either —
`(rm ...)` still propagates the subshell's status as the last one.

So the transform must be able to declare "this statement is bookkeeping; its
status is not observable". The cleanest form is a status-neutral marker on the
exec (or a NoStatus wrapper) that every renderer honors by saving and
restoring `_sh_rc` around it — which matches bash, where the teardown is
renderer bookkeeping rather than a statement the user wrote. That is a
shared-core change (ir.rs + the renderers that must honor it), so it belongs
in the core worker's queue.
