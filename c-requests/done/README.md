# c-requests/ — escalation channel: cpp-sh-go -> the c-sh-go owner

When the C++ frontend hits a genuine SHARED-LOWERING limitation in the
C frontend's code (a construct the clib lowering drops, misrenders, or
cannot express — never a C++-surface bug), its `pi` invocation is told
to APPEND a structured request here instead of touching c-sh-go-owned
files. The c-sh-go worker implements c-requests; the cpp worker never
modifies C-owned code (CPP_PLAN §3–§4).

## Request file format

One file per request: `c-requests/<name>-<YYYYMMDD-HHMMSS>.md`

```markdown
# cpp: <one-line summary>

## NEED
What the shared lowering must provide (a test-string form, a call
shape, a node, a fold...).

## WHY
The failing case / Unsupported reason that prompted this.

## MINIMAL-C-CHANGE
The smallest edit to c-sh-go-owned code that satisfies the NEED.

## FAILING-CASE
The cpp testdata file + expected stdout (the ACCEPTANCE TEST — lives in
cpp-owned territory, so it travels with the request).

## VALIDATION
The exact `make test-cpp` target(s) that prove the feature works once
the change lands.
```

## Semantics

- **Non-blocking.** The cpp worker appends the request and keeps working
  on cpp-owned surface. No `sleeping-` marker — that trap machinery is
  for repeated gate FAILURES (cpp -> core via `--worker-trapped`), not
  for planned extension needs.
- **The c-sh-go worker implements on its normal cycle.** Acceptance =
  BOTH gates green: `make test` (the C corpus — proves C didn't break)
  AND the request's VALIDATION target (proves the feature works).
- **Close the loop:** the c-sh-go worker moves the request to
  `c-requests/done/`; the cpp worker's next cycle sees it, runs its full
  gate, and removes any pin it added.
- **Keep the channel rare.** Only *behavior-changing* edits to C-owned
  code request. C-neutral additions live in cpp-sh-go's own files
  (package-level state is visible to the shared lowering). Constant
  requests are the diagnostic that the ownership line is drawn wrong.
