# core-requests/ — escalation channel: workers -> the shared core

When a per-worktree backend worker or per-frontend worker hits a genuine
shared-core limitation, it escalates. **The artifact type depends on the
need (PLAN §11 marketplace — the core is LLM-free):**

| Need | Artifact | Where | What the core does |
|---|---|---|---|
| A NEW CONTRACT NODE (a shIR statement/expression the frontend emits and backends must ingest) | a **`contract-gen` spec** (JSON) | `core-requests/contracts/<node>.json` | `harness/contract-gen` generates the patch (enum + serde + schema + round-trip fixture); the sweep builds/tests/logs |
| A NEW NODE **+ ITS CONSUMING TRANSFORMS** (one or more — different backends may lower the same node differently) | a **bundle**: `bundle.json` (spec + manifest) + `transforms/*.rs` (each with its own §11.4 manifest) | `core-requests/bundles/<name>/` | atomic on the core: `contract-gen` emits the node patch, the sweep applies node + ALL transforms, builds+gates the pair, logs ONE verdict, reverts WHOLE on failure. Acceptance stays per-transform: each backend's gate decides accept/reject |
| A NEW TRANSFORM (a lowering the backend wants, shared or scoped) | an **`.rs` transform with a manifest** | `core-requests/transforms/offered/<name>.rs` | `harness/core-sweep.sh` builds + gates it; each backend's gate verdict = accept/reject |
| A BUG in an existing shared analysis (DCE, lifetimes, var_types…) | a **`.md` request** | `core-requests/<lang>-<ts>.md` | the estree worker mediates + fixes (the core's remaining non-mechanical surface) |

**Blind escalations are the anti-pattern**: a worker that cannot build must
diagnose its own gate log and file a SPEC or OFFER with the concrete
change — never an `.md` that says "inspect my log".

## The contract-gen spec format (for NEW NODES)

```json
{
  "node": "ForInit",
  "kind": "stmt",                       // stmt | expr
  "fields": {
    "init": {"kind": "stmts"},          // expr | stmts | stmt
    "cond": {"kind": "expr", "required": true},
    "step": {"kind": "stmts"},
    "body": {"kind": "stmts"}
  },
  "sample": {}                          // optional fixture field values
}
```

Run `harness/contract-gen <spec>.json` to see the generated patch (ir.rs
enum variant, shir_json serializer arm, shir_json_in deserializer arm,
schema entry, round-trip fixture). Application precondition (PLAN §11.9):
the OPEN node model — renderers' node-model matches have `_ => refuse`
fallbacks, so the new variant compiles everywhere untouched.

## The bundle format (NEW NODE + its transforms)

A bundle directory = one contract node + one or more transforms that
consume it (different backends may want different lowerings — e.g. a
static try/finally vs a runtime cleanup list). Atomicity is on the CORE
side: node + all transforms apply as one unit, build+gate as one pair,
revert WHOLE on failure. Acceptance stays per-transform: each backend's
gate verdict on ITS transform set decides accept/reject (a backend can
accept the node and one lowering while rejecting another).

```
bundles/<name>/
  bundle.json        # {"spec": {contract-gen spec}, "manifest": {…}}
  transforms/*.rs    # one per lowering; each carries the §11.4 manifest,
                     # with `depends: [<Node>]` naming its prerequisite node
```

`harness/contract-gen bundles/<name>/bundle.json` emits the node patch +
the manifest block; `harness/core-sweep.sh --bundles` validates spec +
manifests (verdicts.log); `--apply-bundles` applies+builds+gates+reverts
(explicit operator mode — the live tree is restored after).

## The transform offer format (for NEW TRANSFORMS)

A complete `.rs` module (like the `src/transforms/` compile-ins) whose doc
header carries the §11.4 manifest:

```rust
//! name: <transform>
//! prereqs: [analyses it needs]
//! invariant: <which A1 shapes it expects/normalizes>
//! scope: <intended acceptors>
//! updates: <old version id if replacing one>
```

Acceptance = the gate verdict: the sweep builds the transform set, each
backend's gate either passes (accept) or fails (the backend reads its
verdict line in `core-requests/transforms/verdicts.log` and fixes its own
offer). Updates to accepted transforms are offers too; when all acceptors
land the new version, the old one is pruned.

## Legacy .md requests

Genuine shared-analysis bugs only (a broken pass, a wrong verdict, a
round-trip gap). Newest-first is honored by the mediation loop; a request
that survives 3 cycles moves to `stalled/` (revisited, never retired).
