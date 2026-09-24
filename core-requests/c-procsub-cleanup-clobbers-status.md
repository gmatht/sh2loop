# C backend / process substitution: the FIFO cleanup `rm` runs BEFORE `$?` is read, clobbering it

**Status:** diagnosed, not fixed. Affects `cmp`/`diff`-style scripts that use
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

## Fix direction

The cleanup must not become the last status write before an observable `$?`
read. Options, in increasing invasiveness:

1. Save/restore around the cleanup: keep the user command's status, run the
   teardown, then restore `_sh_rc` (`{ int _rcs = _sh_rc; rm…; _sh_rc = _rcs; }`).
2. Order the teardown AFTER the `$?` consumer when the consumer is adjacent
   (needs a liveness/adjacency analysis — more invasive).
3. Model the cleanup as not affecting `$?` at all (a property on the emitted
   site), which is what bash effectively does — the teardown is renderer
   bookkeeping, not a shell statement the user wrote.

Option 1 is the smallest and safest, and is local to the process-substitution
lowering. Option 3 is the most principled if the transform layer can carry
such a flag.

## Reproduction

    ./setup_backends.sh --backend-gate c        # 070_cmp_basic.sh fails
    cd /tmp && bash /home/llm/sh2loop/sh2perl/examples/070_cmp_basic.sh > b.out
    # render + compile the same file for C, run with argv0 matched for $0:
    # bash -c 'exec -a "$0" "$1"' <script> <bin> > c.out
    diff b.out c.out      # -> "bc -s exit: 1" vs "0"
