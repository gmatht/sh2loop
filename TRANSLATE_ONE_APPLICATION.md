# TRANSLATE_ONE_APPLICATION

Playbook: translate a specific application from a source language to a
target language, when the translation pipeline is not yet able to do the
translation, and the user provides tests the translated application must
pass.

Derived from the sh2perl workspace's frontend/backend/fleet experience
(the oracle-driven ladders, the split settlement, the array-base saga,
the worker fleet). It is a *method*, not a tool; apply it to any
source/target pair.

## The principle

The user's tests are the **acceptance anchor**, but they are far too
coarse to drive the work — a failing integration test cannot say which
construct is broken. The engine is a **finer-grained construct ladder
derived from the app itself**, probe-verified against the *source's*
behavior, ordered by dependency. You do not translate the app — you grow
the pipeline until the app's footprint is covered, with the user's tests
as the milestone gate.

## The method

### 1. Triangulate the oracle first

"Correct" must be decided before any code.

- Source language has a reference implementation (bash, CPython, …): the
  source's *observable behavior* is the anchor. The translation is
  correct iff it reproduces it (stdout, exit codes, side effects) —
  never "what a native target program would do". Pin the reference
  version (bash 3.2 vs 5.2 differ on `${a[-1]}`, etc.).
- No reference: the user's own acceptance run on the real app is the
  anchor; hand-verify a curated subset.

Structural tests mean nothing until the behavioral side is anchored.

### 2. Enumerate the app's language footprint

Run the source through the existing frontend/parser; list the constructs
it *actually uses* — most apps touch a small slice of the language.
Order by dependency (literals → assignment → control flow → data
structures → I/O → the app's own idioms). This is the app's dialect,
not the whole language (YAGNI).

### 3. Write a minimal probe per construct

For each construct, the smallest program exercising it — one construct
per probe, side-effect-free, deterministic (no real files, no network,
no env dependence, no timing). The oracle is the source's behavior.
These probes are the fast inner loop; the user's tests are the slow
integration gate. One construct per probe is what gives clean
attribution when something fails.

### 4. Classify every probe before implementing (the expressible-intersection check)

Run the full pipeline (parse → IR → emit → execute → compare) on each
probe. On failure, classify *why*:

- **(a) contract/IR gap** — the shape cannot be expressed in the middle
  representation → a core change, queued separately (in this workspace:
  a core request). The translator must not fork the shared core.
- **(b) frontend gap** — the source construct is not parsed yet.
- **(c) backend gap** — the IR is fine, the target renderer can't emit it.
- **(d) semantic divergence** — the construct means something different
  in the source than in the contract's home semantics (zsh 1-based
  arrays, no word-split, inclusive substrings). The recurring hard case.

**Refuse > guess**: anything unclassified stays unimplemented and fails
loud, never half-translated. Clean attribution is what makes the whole
loop work.

### 5. Drive implementation with the failure loop

Red probe → implement the cheapest correct lowering for *that* probe →
re-run **the whole ladder** (not just the new test) → commit only when
everything previously green stays green; otherwise revert. Never bless a
regression. Sequence by dependency — a construct goes green only after
its dependencies.

### 6. Handle semantic divergence explicitly

In order of preference:

1. **Canonicalize in the frontend** — normalize the source construct to
   the contract's canonical form at parse time (zsh `$a[2]` →
   `arrayIndex(a,1)`), so every backend stays dumb.
2. **Carry a semantics manifest** — only if normalization is impossible;
   it forces every backend to re-implement the semantics.
3. **Declare the boundary** — if the target genuinely cannot express the
   behavior, that user test is a *real constraint*: scope the
   translation (the test stays unimplemented, documented) or grow the
   target. The user's suite is the arbiter — never silently approximate.

The oracle for divergence is always the **source's native behavior**,
never the contract's home semantics.

### 7. Integrate with attribution

When the ladder is green, run the user's suite. Each failure bisects:
reduce the app to the smallest failing slice, add it as a probe — it
becomes a permanent regression pin. The user's tests, once green, are
blessed as the app's contract.

## The mining loop (automation)

Read the app source, find difficult idioms, add them as standalone
tests, translate, fix, repeat:

1. **Mine by gap, not by "difficulty".** The difficulty signal is the
   pipeline's own failure output: constructs that fail today (unsupported
   markers, red probes), constructs with no covering probe in the ladder,
   ranked by app frequency. Already-green constructs are skipped.
   Semantic-divergence constructs route to the design fork (step 6),
   never to the fix loop.
2. **Extract atoms first, then the compound idiom.** Real-app idioms are
   compounds; a copied snippet fails for several reasons at once. Land
   each atomic construct as a minimal probe, then reassemble the idiom
   as an integration test once the atoms are green.
3. **The oracle is the source's native run** of each extracted example.
4. **The fix loop has a no-regression guard** (step 5) and an escalation
   path: a test red for N iterations with no progress → design decision /
   core request, not more grinding.
5. **Termination is defined.** The loop converges when every mined idiom
   and atom is green AND the user's acceptance tests pass with the app
   itself as the final integration test. Two degenerate states to design
   against: re-adding the same idiom (dedupe against the ladder — the
   ladder is the registry) and mining only constructs nothing fails on
   (the gap classification prevents this).
6. **Caveat:** the loop optimizes for *this app* — the ladder becomes the
   app's dialect. Correct for the stated goal; do not mistake a converged
   app-loop for a complete translator.

## The worker fleet

**Sizing principle: workers = disjoint scope partitions, not
parallelism.** The bottleneck is the serial dependency chain (frontend
must match the core's shapes; backend consumes them). Over-queuing adds
contention (two workers with the same file in scope commit over each
other) and cost, without moving the chain.

For one app, one source language, one target — **3 AI workers + 1
deterministic script + the orchestrator**:

1. **Core/contract worker** — single owner of the shared IR, the
   contract, the oracle harness, the shared ladder infrastructure.
   Everything else queues to it. Highest priority (it unblocks everyone).
2. **Source-frontend worker** — owns the source parser and its ladder
   (the mined atoms + idiom compounds).
3. **Target-backend worker** — owns the renderer, the target runtime,
   the target-side tests.
4. *(Optional)* **Idiom-triage worker** — only for genuinely novel
   idioms: given an unmapped construct, produce a minimal probe and
   classify it into the gap taxonomy. Judgment-heavy, low-volume; can be
   folded into the frontend worker if the app is ordinary.

**The miner is a deterministic script, not an AI worker.** AST walk →
construct inventory → gap scan → templated minimal probes. AI-generated
probes are a poisoned-oracle risk — a hallucinated expected output
trains the whole loop wrong. AI enters only at the classification fork.

**Worker mechanics** (each worker): gate (build + oracle on its scope) →
red → invoke a cheap fast agent (scoped prompt, xhigh thinking) →
re-verify the whole ladder → commit only when everything previously
green stays green → auto-revert on regression → 3 consecutive failures →
structured core request (NEED / WHY / MINIMAL-CORE-CHANGE /
FAILING-CASE) + sleep until the core worker wakes it.

**Model split:** cheap fast models in the loop (self-correcting via the
oracle); the orchestrator (human or strong model) defines the oracle,
decides the divergence forks, and runs the user's suite at milestones.
Cheap models making design decisions cost hours per error.

**Scaling:** +1 backend worker per extra target language (disjoint
worktrees); +1 frontend worker per extra source language. The formula is
always: **1 core + 1 per source frontend + 1 per target backend**, and
never two workers with the same file in scope.

## Guardrails

- The user's tests answer "does the translated app work?"; the probes
  answer "which construct is broken, and why?"; the classification
  answers "can we fix it here, or is it a boundary we must declare?".
  All three are needed; the first alone produces a red screen with no
  way forward, the third is what keeps the work honest.
- Never bless a regression; regressions get reverted, not allowlisted.
- Translators must never modify the shared core directly — queue.
- Probes stay hermetic and deterministic; the oracle version is pinned.
- Time-box traps; escalate instead of grinding.

## First hour checklist

1. Run the app through the source parser → construct inventory.
2. Write top-of-ladder probes + one representative user test end-to-end
   to see the pipeline's current failure mode.
3. Classify every probe into (a)–(d) — this produces the work plan.
4. If any (d): write up the divergence with the failing case and the
   normalization options — that decision gates the rest.
5. Start the fleet: 1 core worker + 1 frontend worker + 1 backend
   worker, scopes disjoint, miner script running.
