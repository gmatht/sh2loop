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

## Translating into a set of languages (multi-target)

The single-target method survives unchanged; what changes is the
hub-and-spoke structure.

1. **One shared ladder + contract, per-target verdicts.** The mined idiom
   atoms are shared (a property of the *source* language). Each target
   runs its own gate over the same ladder. Gap classification is
   per-(source, target): the same probe can be a backend gap for one
   target and green for another; the semantic-divergence outcome can
   differ per target (a construct the contract cannot carry may be
   natively expressible in one target and not another). The contract
   stays target-neutral — all target-specific divergence lives in the
   renderers.
2. **Target order matters.** Prove the contract with the most expressive
   target first (fewest divergence forks), then add cheaper targets. The
   canonical form of each construct is decided once, in the contract,
   and every target inherits it — never re-litigate a shape per backend.
3. **Sync discipline.** Per-target branches; merge main into each BEFORE
   every verification; renderers never touch the shared core; the core
   is single-owner. Conflicts stay per-branch.
4. **Fleet scales additively.** 1 core + 1 frontend per source language
   + 1 backend per target, load-gated with the core first. The
   dependency chain is unchanged per target — targets are parallel
   after the contract is stable.
5. **Integration per target.** The app is the final integration test in
   each target; acceptance is source-behavior == translated-behavior per
   target, never cross-target byte-equality (targets render
   idiomatically — same semantics, different bytes).

## Accepting contributions back (without overwriting)

The failure mode: a contributor works from a snapshot, the acceptor's
 tree moved, and a blind apply clobbers concurrent work. The fix is an
acceptance discipline: **contributions are accepted as tests + spec +
per-scope deltas — never full-file overwrites, and never against the
live tree.**

1. **Ladder tests and mined idioms** — purely additive; accepted as-is.
   They go red until the pipeline implements them; red is the engine,
   not an error.
2. **Contract extensions** — accepted as SPEC (failing case + minimal
   shape change), queued to the core owner, implemented against the
   current tree. Never applied as a patch to the core.
3. **Backend improvements** — accepted as per-backend branch deltas,
   merged only when they do not touch the shared core; conflicts
   resolved per-branch, never force-applied.
4. **Core changes** — never accepted as patches at all. The core moves
   under both sides; a blind merge would clobber one of them. The
   contributor's intent (failing case + minimal change) is queued as a
   request and reimplemented by the core owner against the current tree.

**Mechanics**: the contribution is diffed against the pinned base SHA it
started from (never the acceptor's live WIP); applied to a staging
branch with 3-way merge; reject on conflict rather than force; the
acceptance gate is the COMBINED test suite — the acceptor's ladders +
the contribution's tests, all green, with the source-native oracle for
every new test. Semantic decisions (divergence forks, oracle changes)
are arbitrated by the contract owner — a contribution proposing
different semantics is a proposal, not a fait accompli.

In this workspace the channels already exist: `core-requests/` for core
intent, `frontends/<lang>/testdata/` + `harness/` for tests,
`backends/<lang>` branches + `--sync` for renderers, and the gitlink
bump as the versioned acceptance point. The one-way rule keeps the
acceptor's private state out of the contribution surface entirely.

The principle: **accept the delta the contribution represents,
re-expressed against the acceptor's current tree and verified by the
combined gate — never the contributor's tree as-is.**

## Git: branch, merge, bisect

They map onto three different problems — isolation, reconciliation,
attribution.

**Branch — isolation.** Per-component worker branches/worktrees make the
single-owner discipline mechanical (a worker cannot commit into another's
files — the failure mode of overlapping scopes). Contribution staging: the
contributor works from a pinned base SHA on their own branch; the acceptor
applies to a STAGING branch, runs the combined gate, then merges. Failed
experiments live on branches or scoped stashes, never on main. Never branch
the shared core: single-owner means its evolution is serial by design.

**Merge — reconciliation.** Sync discipline: merge main into each worker
branch BEFORE every verification — conflicts surface early, while small.
Acceptance gate: contribution → staging → merge main in → combined suite
all green → merge to main. Merge is the moment of acceptance, gated by the
suite, never by textual agreement. Scoped merges: never merge a commit
that touches the shared core; a conflict in a shared-owner file is a stop
signal — queue a request, don't force. The gitlink bump is the cross-repo
merge: the workspace merges a pointer, not sh2perl's tree.

**Bisect — attribution.** For when the no-regression guard and one-construct
attribution fail: integration regressions (a probe green in isolation, red
inside a compound idiom), corpus drift, contention between two workers on
a shared file. Its power depends on the playbook's habits: small atomic
commits (one construct each) keep the range tiny; one-construct probes
make the GOOD/BAD check cheap. Preconditions: the failure must be
deterministic (nondeterminism cannot be bisected), and there must be a
range (a never-implemented feature has nothing to bisect; a
semantic-divergence bug has no single causing commit — which is why
divergence forks never enter the fix loop).

Combined: branch = who can touch what; merge = when and how changes
become shared; bisect = which change broke what.

## Accepting contributions — full plan (core worker as evaluator)

### Roles

- **Core worker**: evaluates contributions, cherry-picks accepted commits,
  runs bisect. Owns the acceptance gate. It polls for pending contributions
  (convention: branches named `contrib/<id>`, or a pending-manifest file)
  in addition to its normal gate cycle.
- **Orchestrator**: arbitrates semantic-divergence forks; the only authority
  that can override a verdict.

### Intake (contributor provides)

1. The pinned base SHA the work started from.
2. A branch (or patch series) of SMALL ATOMIC commits — one construct /
   one change per commit, each with its own tests. This is a quality
   requirement AND the precondition that makes bisect effective.
3. New tests: additive, with source-native oracles, hermetic and
   deterministic.
4. Core intent as SPEC files (NEED / WHY / MINIMAL-CORE-CHANGE /
   FAILING-CASE) — never code commits touching the shared core.
5. Scope declared per commit (frontend / backend / harness / …).

Anything that cannot be reduced to atomic commits is rejected at intake.

### Staging evaluation (core worker, in a worktree — never the live tree)

1. `git worktree add` at the pinned base; apply the series (cherry-pick,
   3-way merge). A conflict = reject or request a rebase, never force.
2. Run the FULL gate on the staged tree: acceptor ladders + contribution
   tests + core unit tests + determinism + corpus byte-identity.
3. Verdicts — the gate is the factual layer; the worker's AI judges only
   scope violations and semantic-divergence proposals:
   - **ACCEPT** — gate green, scope rules respected.
   - **ACCEPT-WITH-CHANGES** — gate green but scope/semantic concerns;
     the worker proposes adjustments preserving the contributor's intent.
   - **REJECT** — gate red; bisect the series to attribute the exact
     failing commit(s); report commit + reason.
   - **DEFER** — touches a semantic-divergence fork; arbitration by the
     orchestrator, not the worker.

### Cherry-pick to main

1. Accepted series cherry-picked ONE COMMIT AT A TIME onto main, the
   combined gate run after each.
2. A cherry-pick that breaks the gate is attributed immediately (it is
   the last commit applied) — fix it or exclude it before continuing.
3. After the full series: the combined gate, then the gitlink bump
   records the acceptance.

### Bisect duties (core worker)

1. **The sieve** — a mixed series (some good, some bad commits): bisect
   the staged series (GOOD = first green, BAD = the red tip) to attribute
   the offending commit; cherry-pick everything except it (and its fix,
   if a later commit repaired it).
2. **Post-acceptance attribution** — a previously-green behavior breaks
   later: bisect `last-green..now-red`, criterion = the failing probe;
   the attributed commit is fixed, reverted, or queued.
3. Mechanics: `git bisect run <hermetic gate script>` in a worktree,
   load-gated. The criterion is a single probe or a corpus subset, never
   the full app suite.
4. Preconditions enforced: deterministic failures only (nondeterministic
   → fix the test first), a range must exist, atomic commits (keeps the
   range small).

### Guardrails

- Never evaluate, cherry-pick, or bisect on the live working tree.
- The gitlink bump is the only main-line write beyond the worker's own
   scoped commits.
- Verdicts are gate-driven; the AI judges scope and semantics, never the
   facts.
- A contribution that cannot be reduced to atomic commits is rejected at
   intake — bisect needs them.

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

## Running the script (translate_one_application.sh)

The playbook is executable: `./translate_one_application.sh` drives the
mine → probe → fix → gate loop with pi (default model deepseek-v4-turbo;
override with `MODEL=`). Detailed flags: run `./translate_one_application.sh
--help`; the template library's extension contract: `templates/README.md`.

```
./translate_one_application.sh mine <app> [--lang sh|zsh|fish|py|pl|go]
./translate_one_application.sh probe                  # oracle verdicts
./translate_one_application.sh fix    [--commit]      # pi repair loop
./translate_one_application.sh gate   [--tests DIR]   # ladder + acceptance
./translate_one_application.sh run    <app> [--iterations N] [--tests DIR]
./translate_one_application.sh dump-templates --lang L # regenerate seeds
```

Workflow (the phase → command mapping):

1. **Mine** — `mine <app>` scans the app's construct footprint and emits
   minimal probe templates (one construct per probe) into
   `.translate-work/probes/` (work dir overridable with `WORK=`).
2. **Probe** — `probe` runs the oracle (source-native vs target) per
   probe and reports verdicts: PASS / MISMATCH / EMIT-FAIL / REFUSE /
   TARGET-ERR (plus the byte-equality note for sh/zsh).
3. **Fix** — `fix` drives pi on each red probe (scoped prompt: probe +
   expected/actual + the discipline + no-regression guard). After
   MAX_ATTEMPTS (default 3) it escalates: a structured core request in
   `core-requests/` and a sleeping marker in the work dir — the probe is
   declared a boundary, not grinded.
4. **Gate** — `gate [--tests DIR]` runs the ladder + the user's
   acceptance tests; reports escalated/queued counts. `run` loops
   mine → fix → gate until green or the iteration cap.
5. **Acceptance** — point `--tests` at the user's tests: they run through
   the same oracle and become the outer gate.

Language: detected from the app extension (sh→bash+posix-sh-go, zsh,
fish, py, pl, go). Target (default estree): `--target estree|perl|c|sh`
(the `--shir-in-<t>` pipe; estree executes end-to-end). `--commit`
stages only `frontends/<lang>/` + `harness/` + `templates/` (never
`git add .`) and is gated on the estree corpus gate. Env: MODEL, THINKING,
WORK, TPLDIR, MAX_ATTEMPTS, MAX_PROBES, TIMEOUT, COMMIT.

Semantic-divergence probes are documented, not forced (the fix prompt
says so); stalled probes escalate to the core queue rather than looping.

## First hour checklist

1. Run the app through the source parser → construct inventory.
2. Write top-of-ladder probes + one representative user test end-to-end
   to see the pipeline's current failure mode.
3. Classify every probe into (a)–(d) — this produces the work plan.
4. If any (d): write up the divergence with the failing case and the
   normalization options — that decision gates the rest.
5. Start the fleet: 1 core worker + 1 frontend worker + 1 backend
   worker, scopes disjoint, miner script running.
