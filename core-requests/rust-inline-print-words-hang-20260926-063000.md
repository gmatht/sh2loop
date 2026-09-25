# rust_backend `inline_print_words` spins forever — `continue` does not advance

STATUS: open (filed 2026-09-26 during the post-reboot fleet restart)
SEVERITY: **fleet-blocking.** It hangs `cargo test --lib`, which holds
`.build-lock`, which queues every backend gate behind it.

## NEED

`debashl::rust_backend::inline_print_words` (src/rust_backend.rs, ~line 1284)
must terminate. As written, two of its three no-match guards `continue` the
outer `loop` **without having consumed or skipped the match**, so the next
iteration's `text.find(pat)` returns the *same* index forever.

## WHY

The function's outer loop is:

```rust
loop {
    let at = match text.find(pat) { Some(a) => a, None => break };
    ...scan to the `]` that closes `vec![`...
    if j >= rest.len() || rest.as_bytes()[j] != b']' {
        continue;                        // <-- line ~1332: NON-ADVANCING
    }
    ...
    if !rest[j..].starts_with(", true, false)") {
        continue;                        // <-- line ~1342: NON-ADVANCING
    }
    ...
    text.replace_range(at..end, &replacement);
}
```

`continue` re-enters the loop; the only way the loop makes progress is the
trailing `replace_range`, which the two `continue`s are precisely the
"we are NOT going to replace this one" paths. Nothing was mutated, so
`find(pat)` rediscovers the identical occurrence and the loop spins.

The `None => break` arm is the only real exit, and it can never be reached
once a match exists whose tail does not match the expected shape.

## EVIDENCE (live, from the rebooted box)

The core worker runs `build-lock.sh --role core -- cargo test --lib` every
iteration. It hung for **20+ minutes** on a single test:

```
test rust_backend::tests::echo_esc_kept_with_dash_e has been running for over 60 seconds
```

The test itself is trivial (`render("echo -e \"$1\"\n")`), so this was not
slowness. The test binary sat at ~104% CPU, `State: S`, `wchan:
futex_wait_queue_me`, 2 threads. `gdb -p <pid> -batch -ex 'thread apply all bt'`:

```
Thread 2 (LWP ...) "rust_backend::t":
#0 core::str::pattern::TwoWaySearcher::next<MatchOnly> (long_period=true)
#1 core::str::pattern::{impl#33}::next_match
#2 core::str::{impl#0}::find
#3 debashl::rust_backend::inline_print_words (text=..., ) at src/rust_backend.rs:1287
#4 debashl::rust_backend::inline_simple_helpers at src/rust_backend.rs:1200
#5 debashl::rust_backend::shir_to_rust at src/rust_backend.rs:2209
#6 debashl::rust_backend::tests::render at src/rust_backend.rs:18088
#7 debashl::rust_backend::tests::echo_esc_kept_with_dash_e at src/rust_backend.rs:19099

Thread 1 (LWP ..., "debashl-d531676"):
#0 syscall
#2 std::sys::sync::thread_parking::futex::Parker::park
#3 std::thread::Thread::park          <-- libtest main, waiting on the hung test thread
```

Frame #3 sitting in `find` at line 1287 across repeated samples is the
signature of "call find in a loop that never advances", not of a slow
search: the search itself is microseconds on inputs of this size (a
standalone `find` over a 400 KB haystack containing the same needle
completes in ~150 µs).

## MINIMAL-CORE-CHANGE

In `inline_print_words`, the two non-advancing `continue`s must instead
**advance past the current match** or stop. The narrowest correct fix is to
track a scan origin and resume the search after `at`:

```rust
fn inline_print_words(text: &mut String) {
    let pat = "__sh_print_words(&[vec![";
    let mut from = 0usize;
    loop {
        let at = match text[from..].find(pat) {
            Some(rel) => from + rel,
            None => break,
        };
        // ... existing scan unchanged ...
        if !shape_matches {
            from = at + pat.len();   // ADVANCE — never re-find the same match
            continue;
        }
        // ... existing replace_range ...
        // replace_range can shrink the text; `at` is still a valid origin
        // for the next search because everything before `at` is untouched.
        from = at;
    }
}
```

(Equivalently: `break` on the non-matching shapes if only the first
occurrence is ever meant to be rewritten — but that changes semantics for
multi-occurrence inputs, so advancing is the safer fix.)

**The same non-advancing `continue` pattern exists in `simplify_let_b`
(src/rust_backend.rs, the `continue` at ~line 1423).** It was not observed
hanging (its `continue` may be reachable only when a later guard already
consumed the match), but it should be audited and fixed in the same pass —
identical shape, identical latent bug. Grep for `continue;` inside any
`loop { let at = ... find ... }` and require that every such arm either
mutates `text` or moves the search origin.

## FAILING CASE

`cargo test --lib --manifest-path sh2perl/Cargo.toml`, test
`rust_backend::tests::echo_esc_kept_with_dash_e` (and any test that calls
`render` → `shir_to_rust` on a script whose rendered text contains a
`__sh_print_words(&[vec![` that does NOT match the `, true, false)` shape).
It hangs forever rather than failing, so it presents as a hung gate, not a
red one.

## IMPACT ON THE FLEET

Because `run_core_worker.sh` runs `cargo test --lib` under
`build-lock.sh --role core`, one hung test held the single build lock and
**starved all 11 backend gates** — every one queued on `flock 9` at
`setup_backends.sh --backend-gate <lang>` with zero cargo progress on an
otherwise idle 16-core box. This is why the fleet looked "up but idle"
after the reboot.

CONFIRMED A SECOND TIME (2026-09-26 ~06:47), on the **rust backend gate's**
own path rather than the core worker's: `./fail-go --rust --gate` builds and
runs `cargo test --lib`, and its test binary again spun at 99% CPU for
15+ minutes inside `inline_print_words` (`rust_backend.rs:1287`), holding
the gate lock the whole time. Same signature:

```
Thread 2 "rust_backend::t":
#0 core::str::pattern::TwoWaySearcher::{byteset_contains,next}<MatchOnly> (long_period=true)
#2 core::str::pattern::{impl#33}::next_match
#3 core::str::{impl#0}::find
#4 debashl::rust_backend::inline_print_words at src/rust_backend.rs:1287
#6 debashl::rust_backend::shir_to_rust at src/rust_backend.rs:2209
#8 debashl::rust_backend::tests::echo_esc_kept_with_dash_e at src/rust_backend.rs:19099
Thread 1: std::thread::Thread::park   <-- libtest waiting on the hung test
```

This makes it a HARD blocker for the whole backend fleet, not just the core:
every gate that builds the corpus runs this test, so the first gate to reach
it wedges the queue. It needs fixing before the fleet can make progress.

## VALIDATION

```
cd sh2perl && timeout 300 cargo test --lib --manifest-path Cargo.toml \
    rust_backend::tests::echo_esc_kept_with_dash_e
```

must terminate well under 300 s (it currently never terminates). Then the
full `cargo test --lib` for the worktree must return to its normal runtime.
