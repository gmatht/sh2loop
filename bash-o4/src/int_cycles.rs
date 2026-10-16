//! int-cycles — worktree-local Int seeding for scalar copy-cycles (O3/O4).
//!
//! Closes the one gap the shared C backend deliberately leaves open: a
//! scalar whose assigns are all int-valued but in MIXED forms — an
//! `arrayIndex` read here, a plain `v=$w` copy there, an arith
//! assignment elsewhere — is pushed `Int` by NEITHER of the backend's
//! two seeders:
//!
//! - `seed_int_element_readers` pushes only vars whose assigns are ALL
//!   `Arith` or ALL reads of a homed array. `rbt_x2` (`RB_PX[$k]` in
//!   `rb_face`, `$rbt_t` in the `rb_tri` swap) fails both arms.
//! - `int_element_verdict`'s greatest-fixpoint seed DOES keep the swap
//!   cycle (`x1=$x2`, `x2=$t`, `t=$x1`), but only as a *seed set* for
//!   the homing analysis — the push gate above still drops every member
//!   with a copy assign, and `demote_stringy_ints` then strips the
//!   members that WERE pushed (`rbt_x2 = $rbt_t` reads non-`Int`
//!   `rbt_t`), cascading the whole per-pixel nest back to `char*`.
//!
//! The game pays for that cascade once per pixel: every `$((...))` on a
//! `char*` var is `snprintf`+`strdup`+`free`, every `[ "$x" -lt ... ]`
//! is two `atoll`s, and the `rb_tri` x/y nest holds ~25 such assigns
//! plus ~30 `atoll` sites per covered pixel (`--emit-c` counts:
//! `rb_tri` 67 `atoll` + 53 `xstrdup`, `rb_frag` 23, `rb_putrun` 20).
//!
//! This pass pushes `Int` for the greatest fixpoint of vars whose every
//! assign is int-valued under transparent-copy semantics — `Arith`,
//! `Int`, canonical-numeric text, `Var`/`getVar` of a member, and
//! `arrayIndex`/`min`/`max`/`sum` over literally-dense int-domain
//! arrays — so the swap hub (`rbt_t`), the loop bounds
//! (`rbt_minx/maxx/...`), the shade (`rbt_sh`), the corner temps and the
//! fragment bridge (`rbp_fsh/fu/fv/fx/fy`) all home as `long long` and
//! the per-pixel loop does direct integer loads.
//!
//! SOUNDNESS (why a worktree-local propose/dispose split is exact):
//! - The pass only PROPOSES: it appends `(name, Int)` to
//!   `prog.var_types`. The backend's `demote_stringy_ints` runs AFTER
//!   (at C ingest) and re-validates every verdict — any member with an
//!   assign demote finds stringy is removed again. A wrong proposal is
//!   a missed optimisation, never a miscompile.
//! - The proposal rule is a SUBSET of demote's own `is_numeric`, except
//!   for `arrayIndex` over arrays the backend did not home — and those
//!   members are exactly what demote strips. Hex/row/param/capture text
//!   (`rb_pxhex`, `rbp_row`, `rbx_s=$1`, `$(...)`) is never proposed.
//! - Copies are representation-transparent (backend module docs): when
//!   every assign holds a canonical integer, `char*` vs `long long`
//!   changes the round-trip, never the meaning. The strict text rule
//!   (no leading zeros, `i64`-parseable) keeps non-canonical text
//!   (`"007"`, `""`, hex) out of the set.
//! - String-observed vars are excluded via a mirrored `str_use` walk
//!   (same rules as the backend's uses pass, including the numeric-test
//!   carve-out), so no proposed var can reach a text observer.
//! - Subshell/background-written vars, `for`-iteration vars, and the
//!   `$?/$#/$!` specials handling mirror the backend's candidate gate.
//!
//! SCOPE (deliberately narrow — everything else stays backend-owned):
//! - Scalar vars only. Array homing is the backend's job; the array rule
//!   here covers ONLY literal-`setArray` tables with int-domain
//!   elements and no appends/reassigns/unsets/indexed stores (the
//!   `RB_P*`/`CUBE_*`/`FACE_N`/`SCOS`/`SSIN` polygon tables). Indexed,
//!   appended, or whole-array string-read tables (`RBTEX_*`, `RFB_ROWS`,
//!   `RB_ORD`, joins/slices/iterations) are rejected, preserving the
//!   backend's verdicts there byte-for-byte.
//! - O3/O4 only, behind `SH2_NO_INT_CYCLES=1` (validation kill-switch,
//!   like `SH2_NO_INT_ELEM=1`); ingress failure returns `false` so a
//!   transform problem can never fail a render that would otherwise
//!   work. `Og`/`O0` stay byte-identical to the CLI.

use debashl::ir::{ArithAst, IrExpr, IrProgram, IrStmt};
use std::collections::{HashMap, HashSet};

/// Seed `Int` verdicts for the scalar copy-cycle closure. Returns true
/// when `prog.var_types` changed.
pub fn seed_int_cycles(prog: &mut IrProgram) -> bool {
    if std::env::var("SH2_NO_INT_CYCLES").as_deref() == Ok("1") {
        return false;
    }
    // Bisection gate (validation only): `SH2_INT_CYCLES_ONLY=a,b,c`
    // restricts proposals to the named vars; `SH2_INT_CYCLES_SKIP=a,b`
    // proposes everything except the named vars. Never set in production.
    let only: Option<HashSet<String>> = std::env::var("SH2_INT_CYCLES_ONLY").ok().map(|s| {
        s.split(',')
            .map(|x| x.trim().to_string())
            .filter(|x| !x.is_empty())
            .collect()
    });
    let skip: HashSet<String> = std::env::var("SH2_INT_CYCLES_SKIP")
        .ok()
        .map(|s| {
            s.split(',')
                .map(|x| x.trim().to_string())
                .filter(|x| !x.is_empty())
                .collect()
        })
        .unwrap_or_default();
    // Existing Int verdicts seed the fixpoint (a var the core already
    // types Int stays trusted — demote re-validates afterward anyway).
    let member: HashSet<String> = prog
        .var_types
        .iter()
        .filter(|(_, t)| *t == debashl::ir::IrType::Int)
        .map(|(n, _)| n.clone())
        .collect();

    let mut cx = Ctx::collect(prog);
    // Candidates: plain idents with at least one scalar assign, never
    // written under copy semantics, never a for-iteration var, never
    // directly string-observed.
    let mut cur: HashSet<String> = HashSet::new();
    for (v, a) in &cx.assigns {
        if a.rhs.is_empty() || a.in_copy {
            continue;
        }
        if !is_ident(v) {
            continue;
        }
        if matches!(v.as_str(), "?" | "#" | "!" | "$") {
            continue;
        }
        if cx.for_vars.contains(v) || cx.str_use.contains(v) {
            continue;
        }
        cur.insert(v.clone());
    }
    // JOINT greatest fixpoint (mirror of the backend's intwrites
    // fixpoint): scalar membership and the array verdict depend on each
    // other (`RB_PX[$k]=$rbp_sx` stores need Int `rbp_sx`; `rbt_x2 =
    // RB_PX[$k]` reads need a homed `RB_PX`). Removal only shrinks, so
    // copy-cycles (`x1=$x2`, `x2=$t`, `t=$x1` — values originate in int
    // stores and only permute) survive while genuinely-stringy vars and
    // their arrays cascade out together.
    loop {
        let mut toss = Vec::new();
        for v in cur.iter() {
            // Pre-seeded Ints are pinned (demote re-validates anyway).
            if member.contains(v) {
                continue;
            }
            let a = &cx.assigns[v];
            if !a
                .rhs
                .iter()
                .all(|e| int_valued(e, &cur, &member, &cx.lit_int_arrays))
            {
                toss.push(v.clone());
            }
        }
        let arr_before = cx.lit_int_arrays.len();
        let tossed = !toss.is_empty();
        for v in toss {
            cur.remove(&v);
        }
        // Re-verdict arrays under the shrunken scalar set (store values
        // that lost Int membership veto their arrays now).
        cx.lit_int_arrays = lit_int_arrays(
            prog,
            &cx.str_read,
            &cx.iterated,
            &cur,
            &cx.assigns,
            &member,
            true,
        );
        if !tossed && cx.lit_int_arrays.len() == arr_before {
            break;
        }
    }
    let mut pushed = 0;
    for v in cur {
        if member.contains(&v) {
            continue;
        }
        if let Some(only) = &only {
            if !only.contains(&v) {
                continue;
            }
        }
        if skip.contains(&v) {
            continue;
        }
        prog.var_types.push((v, debashl::ir::IrType::Int));
        pushed += 1;
    }
    if pushed > 0 {
        prog.var_types.sort_by(|a, b| a.0.cmp(&b.0));
    }
    if std::env::var("SH2_DEBUG_INT_CYCLES").is_ok() {
        eprintln!("INT_CYCLES pushed {pushed}");
    }
    if std::env::var("SH2_DEBUG_INT_CYCLES").as_deref() == Ok("2") {
        let mut v: Vec<_> = cx.lit_int_arrays.iter().collect();
        v.sort();
        eprintln!("INT_CYCLES arrays: {:?}", v);
    }
    pushed > 0
}

/// Int-valued under the current fixpoint membership: `Arith`/`Int`
/// nodes, canonical-numeric text, transparent copies of members or
/// pre-seeded Ints, `param` len/`#`, and reads over literally-dense
/// int-domain arrays.
fn int_valued(
    e: &IrExpr,
    cur: &HashSet<String>,
    seeded: &HashSet<String>,
    arrays: &HashSet<String>,
) -> bool {
    match e {
        IrExpr::Int(_) | IrExpr::Arith(_) => true,
        // Strict canonical-numeric text: non-empty, all digits after an
        // optional `-`, parses as `i64`, and NO leading zeros (`"007"`
        // prints differently from an Int home — never propose it).
        IrExpr::Str(s, _) => {
            let t = s.trim();
            !t.is_empty()
                && t.strip_prefix('-')
                    .unwrap_or(t)
                    .bytes()
                    .all(|c| c.is_ascii_digit())
                && !(t.len() > 1 && (t.starts_with('0') || t.starts_with("-0")))
                && t.parse::<i64>().is_ok()
        }
        IrExpr::Var(n, _) | IrExpr::Ident(n) => {
            if matches!(n.as_str(), "?" | "#" | "!" | "$") {
                return true;
            }
            if is_positional(n) {
                return true;
            }
            cur.contains(n) || seeded.contains(n)
        }
        IrExpr::Call { func, args } if func == "getVar" => match str_arg(args, 0).as_deref() {
            Some(n) => {
                if matches!(n, "?" | "#" | "!" | "$") {
                    return true;
                }
                if is_positional(n) {
                    return true;
                }
                cur.contains(n) || seeded.contains(n)
            }
            None => false,
        },
        IrExpr::Call { func, args } if func == "arrayIndex" => {
            matches!(str_arg(args, 0).as_deref(), Some(n) if arrays.contains(n))
        }
        IrExpr::Call { func, args } if matches!(func.as_str(), "min" | "max" | "sum") => {
            matches!(str_arg(args, 0).as_deref(), Some(n) if arrays.contains(n))
        }
        // NOTE: no `param` arm on purpose. The backend's own
        // `is_numeric` accepts `param("len" | "#")` (the argument-count
        // forms), but every `#`-first call in real programs is the 3-arg
        // suffix-strip (`${v#pat}` — e.g. `pl_secs=${pl_note#* }` =
        // `"0.15"`, a DECIMAL that truncates under an Int home). The
        // count forms never occur here; strips must never propose.
        _ => false,
    }
}

/// First string arg of a call, if present (mirror of the backend's
/// private `str_arg`).
fn str_arg(args: &[IrExpr], i: usize) -> Option<String> {
    match args.get(i) {
        Some(IrExpr::Str(s, _)) => Some(s.clone()),
        _ => None,
    }
}

/// A positional param (`$1`..`$9`, `${10}`…): the caller's argv string,
/// whatever it is. Converting it once with `atoll` observes exactly
/// what every per-use `atoll` observes, so positionals are int-valued
/// sources (mirrors the backend's `is_positional`; `$0` is excluded —
/// the program name is not numeric). String-observed vars are still
/// gated by `str_use`, and demote re-validates, so a text-observed
/// positional can never mistype.
fn is_positional(n: &str) -> bool {
    !n.is_empty() && n != "0" && n.bytes().all(|b| b.is_ascii_digit())
}

/// Shell identifier (mirror of the backend's `is_ident`).
fn is_ident(s: &str) -> bool {
    let mut cs = s.chars();
    match cs.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    cs.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

struct Assigns {
    rhs: Vec<IrExpr>,
    in_copy: bool,
}

/// Collected program facts for the fixpoint.
struct Ctx {
    assigns: HashMap<String, Assigns>,
    /// `for x in ...` iteration vars (never proposed — the element type
    /// is the backend's call).
    for_vars: HashSet<String>,
    /// Directly string-observed vars (mirror of the backend's `str_use`).
    str_use: HashSet<String>,
    /// Whole-array string-read arrays (joins/slices — veto array homing).
    str_read: HashSet<String>,
    /// By-value iterated arrays (veto array homing).
    iterated: HashSet<String>,
    /// Literally-dense int-domain arrays (see module docs).
    lit_int_arrays: HashSet<String>,
}

impl Ctx {
    fn collect(prog: &IrProgram) -> Self {
        let mut assigns: HashMap<String, Assigns> = HashMap::new();
        collect_assigns(&prog.stmts, &mut assigns, false);
        for sub in &prog.subs {
            collect_assigns(&sub.body, &mut assigns, false);
        }
        let mut for_vars = HashSet::new();
        collect_for_vars(&prog.stmts, &mut for_vars);
        for sub in &prog.subs {
            collect_for_vars(&sub.body, &mut for_vars);
        }
        let mut str_use = HashSet::new();
        let mut str_read = HashSet::new();
        let mut iterated = HashSet::new();
        let array_names = array_names(&assigns, prog);
        walk_uses_list(
            &prog.stmts,
            &mut str_use,
            &mut str_read,
            &mut iterated,
            &array_names,
        );
        for sub in &prog.subs {
            walk_uses_list(
                &sub.body,
                &mut str_use,
                &mut str_read,
                &mut iterated,
                &array_names,
            );
        }
        let lit = lit_int_arrays(
            prog,
            &str_read,
            &iterated,
            &HashSet::new(),
            &assigns,
            &HashSet::new(),
            false,
        );
        Ctx {
            assigns,
            for_vars,
            str_use,
            str_read,
            iterated,
            lit_int_arrays: lit,
        }
    }
}

/// Scalar assigns + `Declare` inits, tracking copy-semantics nesting
/// (subshell/background bodies write copies, not the live var).
fn collect_assigns(stmts: &[IrStmt], out: &mut HashMap<String, Assigns>, in_copy: bool) {
    for s in stmts {
        match s {
            IrStmt::Assign { targets, expr, .. } => {
                for t in targets {
                    if t.indices.is_empty() && !t.var.contains('[') {
                        let a = out.entry(t.var.clone()).or_insert(Assigns {
                            rhs: Vec::new(),
                            in_copy: false,
                        });
                        a.rhs.push(expr.clone());
                        a.in_copy |= in_copy;
                    }
                }
            }
            IrStmt::Declare { vars, init, .. } => {
                for v in vars {
                    let a = out.entry(v.name.clone()).or_insert(Assigns {
                        rhs: Vec::new(),
                        in_copy: false,
                    });
                    if let Some(e) = init {
                        a.rhs.push(e.clone());
                    }
                    a.in_copy |= in_copy;
                }
            }
            IrStmt::If {
                then,
                elsifs,
                else_,
                ..
            } => {
                collect_assigns(then, out, in_copy);
                for (_, b) in elsifs {
                    collect_assigns(b, out, in_copy);
                }
                collect_assigns(else_, out, in_copy);
            }
            IrStmt::While { body, .. }
            | IrStmt::DoWhile { body, .. }
            | IrStmt::For { body, .. }
            | IrStmt::Block(body) => collect_assigns(body, out, in_copy),
            IrStmt::Subshell(body) | IrStmt::Background(body) => collect_assigns(body, out, true),
            IrStmt::ForInit {
                init, step, body, ..
            } => {
                collect_assigns(init, out, in_copy);
                collect_assigns(step, out, in_copy);
                collect_assigns(body, out, in_copy);
            }
            IrStmt::Function {
                body, named_blocks, ..
            } => {
                collect_assigns(body, out, in_copy);
                for (_, b) in named_blocks {
                    collect_assigns(b, out, in_copy);
                }
            }
            IrStmt::Try {
                body,
                excepts,
                else_body,
                finally_body,
                ..
            } => {
                collect_assigns(body, out, in_copy);
                for e in excepts {
                    collect_assigns(&e.body, out, in_copy);
                }
                collect_assigns(else_body, out, in_copy);
                collect_assigns(finally_body, out, in_copy);
            }
            IrStmt::Case { clauses, .. } => {
                for c in clauses {
                    collect_assigns(&c.body, out, in_copy);
                }
            }
            IrStmt::Select { clauses } => {
                for c in clauses {
                    collect_assigns(&c.body, out, in_copy);
                }
            }
            IrStmt::Redirect { inner, .. } => collect_assigns(inner, out, in_copy),
            IrStmt::Pipeline { stages, .. } => {
                for st in stages {
                    collect_assigns(st, out, in_copy);
                }
            }
            IrStmt::Shaderize { body, .. } => collect_assigns(body, out, in_copy),
            _ => {}
        }
    }
}

/// Every `for x in ...` iteration var.
fn collect_for_vars(stmts: &[IrStmt], out: &mut HashSet<String>) {
    for s in stmts {
        match s {
            IrStmt::For { var, body, .. } => {
                if !var.is_empty() {
                    out.insert(var.clone());
                }
                collect_for_vars(body, out);
            }
            IrStmt::If {
                then,
                elsifs,
                else_,
                ..
            } => {
                collect_for_vars(then, out);
                for (_, b) in elsifs {
                    collect_for_vars(b, out);
                }
                collect_for_vars(else_, out);
            }
            IrStmt::While { body, .. }
            | IrStmt::DoWhile { body, .. }
            | IrStmt::Block(body)
            | IrStmt::Subshell(body)
            | IrStmt::Background(body) => collect_for_vars(body, out),
            IrStmt::ForInit {
                init, step, body, ..
            } => {
                collect_for_vars(init, out);
                collect_for_vars(step, out);
                collect_for_vars(body, out);
            }
            IrStmt::Function {
                body, named_blocks, ..
            } => {
                collect_for_vars(body, out);
                for (_, b) in named_blocks {
                    collect_for_vars(b, out);
                }
            }
            IrStmt::Try {
                body,
                excepts,
                else_body,
                finally_body,
                ..
            } => {
                collect_for_vars(body, out);
                for e in excepts {
                    collect_for_vars(&e.body, out);
                }
                collect_for_vars(else_body, out);
                collect_for_vars(finally_body, out);
            }
            IrStmt::Case { clauses, .. } => {
                for c in clauses {
                    collect_for_vars(&c.body, out);
                }
            }
            IrStmt::Select { clauses } => {
                for c in clauses {
                    collect_for_vars(&c.body, out);
                }
            }
            IrStmt::Redirect { inner, .. } => collect_for_vars(inner, out),
            IrStmt::Pipeline { stages, .. } => {
                for st in stages {
                    collect_for_vars(st, out);
                }
            }
            IrStmt::Shaderize { body, .. } => collect_for_vars(body, out),
            _ => {}
        }
    }
}

/// Array names: every scalar-assign target with an index, every baked
/// `A[k]` target, every `setArray`/`setArrayAppend` callee.
fn array_names(assigns: &HashMap<String, Assigns>, prog: &IrProgram) -> HashSet<String> {
    let mut out = HashSet::new();
    for v in assigns.keys() {
        if let Some((base, _)) = split_baked(v) {
            out.insert(base);
        }
    }
    fn walk(stmts: &[IrStmt], out: &mut HashSet<String>) {
        for s in stmts {
            match s {
                IrStmt::Assign { targets, .. } => {
                    for t in targets {
                        if let Some((base, _)) = split_baked(&t.var) {
                            out.insert(base);
                        }
                    }
                }
                IrStmt::If {
                    then,
                    elsifs,
                    else_,
                    ..
                } => {
                    walk(then, out);
                    for (_, b) in elsifs {
                        walk(b, out);
                    }
                    walk(else_, out);
                }
                IrStmt::While { body, .. }
                | IrStmt::DoWhile { body, .. }
                | IrStmt::For { body, .. }
                | IrStmt::Block(body)
                | IrStmt::Subshell(body)
                | IrStmt::Background(body) => walk(body, out),
                IrStmt::ForInit {
                    init, step, body, ..
                } => {
                    walk(init, out);
                    walk(step, out);
                    walk(body, out);
                }
                IrStmt::Function {
                    body, named_blocks, ..
                } => {
                    walk(body, out);
                    for (_, b) in named_blocks {
                        walk(b, out);
                    }
                }
                IrStmt::Try {
                    body,
                    excepts,
                    else_body,
                    finally_body,
                    ..
                } => {
                    walk(body, out);
                    for e in excepts {
                        walk(&e.body, out);
                    }
                    walk(else_body, out);
                    walk(finally_body, out);
                }
                IrStmt::Case { clauses, .. } => {
                    for c in clauses {
                        walk(&c.body, out);
                    }
                }
                IrStmt::Select { clauses } => {
                    for c in clauses {
                        walk(&c.body, out);
                    }
                }
                IrStmt::Redirect { inner, .. } => walk(inner, out),
                IrStmt::Pipeline { stages, .. } => {
                    for st in stages {
                        walk(st, out);
                    }
                }
                IrStmt::Expr(e) => walk_expr_arrays(e, out),
                _ => {}
            }
        }
    }
    fn walk_expr_arrays(e: &IrExpr, out: &mut HashSet<String>) {
        match e {
            IrExpr::Call { func, args } if func == "setArray" || func == "setArrayAppend" => {
                if let Some(n) = str_arg(args, 0) {
                    out.insert(n);
                }
            }
            IrExpr::Call { args, .. } => {
                for a in args {
                    walk_expr_arrays(a, out);
                }
            }
            IrExpr::Array(items) => {
                for a in items {
                    walk_expr_arrays(a, out);
                }
            }
            IrExpr::Arrow(stmts) => walk(stmts, out),
            _ => {}
        }
    }
    walk(&prog.stmts, &mut out);
    for sub in &prog.subs {
        walk(&sub.body, &mut out);
    }
    out
}

/// Split a baked `A[k]` target into base + key (mirror of the backend's
/// `split_baked`).
fn split_baked(t: &str) -> Option<(String, String)> {
    let (base, rest) = t.split_once('[')?;
    if !is_ident(base) {
        return None;
    }
    let key = rest.strip_suffix(']')?.trim().to_string();
    Some((base.to_string(), key))
}

/// Refs (`$x` / `${x...}`) inside a `test` text + whether the text reads
/// text (mirror of the backend's `test_refs`): pure numeric comparisons
/// read numerically, anything else reads text.
fn test_refs(t: &str) -> (Vec<String>, bool) {
    let mut all: Vec<String> = Vec::new();
    let mut i = 0usize;
    let b = t.as_bytes();
    while i < b.len() {
        if b[i] != b'$' {
            i += 1;
            continue;
        }
        i += 1;
        if i >= b.len() {
            break;
        }
        if b[i] == b'{' {
            i += 1;
            let st = i;
            while i < b.len() && b[i] != b'}' {
                i += 1;
            }
            let inner = &t[st..i.min(b.len())];
            let nm = inner
                .trim_start_matches(['#', '!'])
                .split(['[', ':', '-', '+', '#', '%', '/'])
                .next()
                .unwrap_or("");
            if is_ident(nm) {
                all.push(nm.to_string());
            }
        } else {
            let st = i;
            while i < b.len() && (b[i].is_ascii_alphanumeric() || b[i] == b'_') {
                i += 1;
            }
            if st != i && is_ident(&t[st..i]) {
                all.push(t[st..i].to_string());
            }
        }
    }
    let has_str = [
        " -z ", "-n ", " = ", " != ", "=~", "-f ", "-d ", "-e ", "-s ", "-r ", "-w ", "-x ", "-L ",
        "-h ", "-v ", "-R ",
    ]
    .iter()
    .any(|op| t.contains(op))
        || !(t.contains("-lt")
            || t.contains("-le ")
            || t.contains("-gt")
            || t.contains("-ge ")
            || t.contains("-eq")
            || t.contains("-ne "));
    (all, has_str)
}

/// Mirror of the backend's uses walk, collecting only `str_use` (direct
/// string observations), `str_read` (whole-array string operations) and
/// `iterated` (by-value array iteration). `int_use` is not needed: the
/// fixpoint only excludes string-observed vars.
fn walk_uses_list(
    stmts: &[IrStmt],
    str_use: &mut HashSet<String>,
    str_read: &mut HashSet<String>,
    iterated: &mut HashSet<String>,
    arrs: &HashSet<String>,
) {
    for s in stmts {
        walk_uses_stmt(s, str_use, str_read, iterated, arrs);
    }
}

fn walk_uses_expr(e: &IrExpr, in_int: bool, str_use: &mut HashSet<String>) {
    match e {
        IrExpr::Arith(a) => walk_uses_arith(a, str_use),
        IrExpr::Var(n, _) | IrExpr::Ident(n) => {
            if !in_int {
                str_use.insert(n.clone());
            }
        }
        IrExpr::Index { key, .. } => {
            walk_uses_expr(key, true, str_use);
        }
        IrExpr::Call { func, args } => {
            if func == "arrayIndex" {
                for a in args.iter().skip(1) {
                    walk_uses_expr(a, true, str_use);
                }
                return;
            }
            if matches!(func.as_str(), "min" | "max" | "sum") {
                for a in args {
                    walk_uses_expr(a, true, str_use);
                }
                return;
            }
            if func == "arrayLen" {
                return;
            }
            if func == "getVar" {
                return;
            }
            if func == "test" {
                if let Some(IrExpr::Str(t, _)) = args.first() {
                    let (refs, has_str) = test_refs(t);
                    if has_str {
                        for r in &refs {
                            str_use.insert(r.clone());
                        }
                    }
                }
                return;
            }
            for a in args {
                walk_uses_expr(a, false, str_use);
            }
        }
        IrExpr::Array(items) => {
            for it in items {
                walk_uses_expr(it, in_int, str_use);
            }
        }
        IrExpr::Interpolate(parts) => {
            for p in parts {
                if let debashl::ir::InterpPart::Expr(x) = p {
                    walk_uses_expr(x, false, str_use);
                }
            }
        }
        IrExpr::BinOp { lhs, rhs, .. } => {
            walk_uses_expr(lhs, in_int, str_use);
            walk_uses_expr(rhs, in_int, str_use);
        }
        IrExpr::Arrow(stmts) => walk_uses_list(
            stmts,
            str_use,
            &mut HashSet::new(),
            &mut HashSet::new(),
            &HashSet::new(),
        ),
        IrExpr::Capture { expr, .. } => walk_uses_expr(expr, false, str_use),
        _ => {}
    }
}

fn walk_uses_arith(a: &ArithAst, str_use: &mut HashSet<String>) {
    match a {
        ArithAst::Num(_) | ArithAst::Sizeof(_) => {}
        // Arithmetic reads are numeric by construction — never string
        // observations (mirror: the backend records `int_use` here).
        ArithAst::Var(_)
        | ArithAst::Ident(_)
        | ArithAst::Index { .. }
        | ArithAst::Bin { .. }
        | ArithAst::Un { .. }
        | ArithAst::Cond { .. }
        | ArithAst::Assign { .. }
        | ArithAst::IncDec { .. }
        | ArithAst::Cast { .. } => {}
    }
    // Silence dead-code warnings for the uninspected shapes: the mirror
    // only needs "arith never string-observes", which holds by shape.
    let _ = (a, str_use);
}

#[allow(clippy::too_many_arguments)]
fn walk_uses_stmt(
    s: &IrStmt,
    str_use: &mut HashSet<String>,
    str_read: &mut HashSet<String>,
    iterated: &mut HashSet<String>,
    arrs: &HashSet<String>,
) {
    let _ = arrs;
    match s {
        IrStmt::Assign { targets, expr, .. } => {
            for t in targets {
                for ix in &t.indices {
                    walk_uses_expr(ix, true, str_use);
                }
                if let Some((_, k)) = split_baked(&t.var) {
                    let (refs, _) = test_refs(&k);
                    for r in &refs {
                        // Baked keys are arithmetic by construction;
                        // nothing string-observed (mirror records int_use).
                        let _ = r;
                    }
                }
            }
            walk_uses_expr(expr, false, str_use);
        }
        IrStmt::Declare { init: Some(e), .. } => {
            walk_uses_expr(e, false, str_use);
        }
        IrStmt::Declare { init: None, .. } => {}
        IrStmt::DeclareArray { elements, .. } => {
            for el in elements {
                walk_uses_expr(el, false, str_use);
            }
        }
        IrStmt::If {
            cond,
            then,
            elsifs,
            else_,
            ..
        } => {
            walk_uses_expr(cond, false, str_use);
            walk_uses_list(then, str_use, str_read, iterated, arrs);
            for (c, b) in elsifs {
                walk_uses_expr(c, false, str_use);
                walk_uses_list(b, str_use, str_read, iterated, arrs);
            }
            walk_uses_list(else_, str_use, str_read, iterated, arrs);
        }
        IrStmt::While { cond, body, .. } | IrStmt::DoWhile { cond, body, .. } => {
            walk_uses_expr(cond, false, str_use);
            walk_uses_list(body, str_use, str_read, iterated, arrs);
        }
        IrStmt::For { var: _, iter, body } => {
            if let IrExpr::Array(items) = iter {
                for it in items {
                    if let IrExpr::Call { func, args } = it {
                        if func == "param" {
                            for a in args {
                                if let IrExpr::Str(nm, _) = a {
                                    iterated.insert(nm.clone());
                                }
                                walk_uses_expr(a, false, str_use);
                            }
                            continue;
                        }
                    }
                    walk_uses_expr(it, false, str_use);
                }
            } else {
                walk_uses_expr(iter, false, str_use);
            }
            walk_uses_list(body, str_use, str_read, iterated, arrs);
        }
        IrStmt::ForInit {
            init,
            cond,
            step,
            body,
            ..
        } => {
            walk_uses_list(init, str_use, str_read, iterated, arrs);
            walk_uses_expr(cond, false, str_use);
            walk_uses_list(step, str_use, str_read, iterated, arrs);
            walk_uses_list(body, str_use, str_read, iterated, arrs);
        }
        IrStmt::Function {
            body, named_blocks, ..
        } => {
            walk_uses_list(body, str_use, str_read, iterated, arrs);
            for (_, b) in named_blocks {
                walk_uses_list(b, str_use, str_read, iterated, arrs);
            }
        }
        IrStmt::Subshell(body) | IrStmt::Background(body) | IrStmt::Block(body) => {
            walk_uses_list(body, str_use, str_read, iterated, arrs)
        }
        IrStmt::Redirect { inner, .. } => walk_uses_list(inner, str_use, str_read, iterated, arrs),
        IrStmt::Pipeline { stages, .. } => {
            for st in stages {
                walk_uses_list(st, str_use, str_read, iterated, arrs);
            }
        }
        IrStmt::Case {
            discriminant,
            clauses,
        } => {
            walk_uses_expr(discriminant, false, str_use);
            for c in clauses {
                walk_uses_list(&c.body, str_use, str_read, iterated, arrs);
            }
        }
        IrStmt::Select { clauses } => {
            for c in clauses {
                walk_uses_list(&c.body, str_use, str_read, iterated, arrs);
            }
        }
        IrStmt::Try {
            body,
            excepts,
            else_body,
            finally_body,
            ..
        } => {
            walk_uses_list(body, str_use, str_read, iterated, arrs);
            for e in excepts {
                walk_uses_list(&e.body, str_use, str_read, iterated, arrs);
            }
            walk_uses_list(else_body, str_use, str_read, iterated, arrs);
            walk_uses_list(finally_body, str_use, str_read, iterated, arrs);
        }
        IrStmt::Expr(e) | IrStmt::Output { value: e, .. } => {
            // Whole-array string operations select here (mirror of the
            // backend's argv-strings arm).
            if let IrExpr::Call { func, args } = e {
                for a in args {
                    if let IrExpr::Str(nm, _) = a {
                        if func == "slice" || func == "arrayItems" || func == "listVar" {
                            str_read.insert(nm.clone());
                        }
                        if func == "sortedBigintJoin" {
                            str_read.insert(nm.clone());
                        }
                    }
                }
            }
            walk_uses_expr(e, false, str_use);
        }
        _ => {}
    }
}

/// Literally-dense int-domain arrays, two classes (mirror of the
/// backend's density + guard rules, restricted to the narrow shapes the
/// scalar leaf needs — everything else stays backend-decided):
/// - Class D (dense literal cover): one literal `setArray` init whose
///   every element is int-domain, no appends, no whole-array reassign,
///   no `unset`, no non-`$var` keys. Constant store keys satisfy
///   `0 <= k < N`. `$var` store keys need no guard proof (Class F,
///   mirrors the backend): the full literal cover leaves no holes,
///   fixed-array stores render the exact `_sh_arr_set` guard in both
///   representations, and reads render the len guard per context — so
///   the old `[ $k -lt N ]` + proven-nonneg requirement (kept for the
///   cursor-buffer documentation) no longer gates eligibility.
/// - Class A (append-only): a seed literal plus append-only growth, no
///   indexed stores at all (appends land exactly at `len`).
///   Whole-array string operations (join/slice/iteration) veto in both
///   classes — joins need `char**`.
fn lit_int_arrays(
    prog: &IrProgram,
    str_read: &HashSet<String>,
    iterated: &HashSet<String>,
    scalars: &HashSet<String>,
    assigns: &HashMap<String, Assigns>,
    seeded: &HashSet<String>,
    strict_stores: bool,
) -> HashSet<String> {
    use IrExpr as E;
    #[derive(Default)]
    struct W {
        lit: Option<Vec<IrExpr>>,
        setarrays: usize,
        append: bool,
        reassign: bool,
        unset: bool,
        /// Dynamic `$var` store keys: (key var, guard in force at the site).
        dyn_keys: Vec<(String, Option<Guard>)>,
        /// Constant store keys (proven below against the cover).
        const_keys: Vec<i64>,
        /// Any other key shape (expression, non-ident var) — vetoes.
        other_key: bool,
        /// Store RHS values (int-domain check at verdict time under
        /// the current scalar membership).
        store_vals: Vec<IrExpr>,
    }
    let mut writes: HashMap<String, W> = HashMap::new();
    // Statement-list walk: array writes + guard collection. Guards are
    // per-statement-list path conditions (`[ $k -lt N ]` on the If arm
    // that encloses a store); the walk threads the active guard set
    // through If/While nests so each dynamic store site records the
    // bound in force exactly there. Keys on this path are baked
    // `A[$k]` target text (structured `indices` never occur here —
    // verified against the game A1).
    fn walk(
        stmts: &[IrStmt],
        writes: &mut HashMap<String, W>,
        guards: &HashMap<String, Guard>,
        assigns: &HashMap<String, Assigns>,
        inc_guards: &mut HashMap<String, Vec<i64>>,
    ) {
        for s in stmts {
            match s {
                IrStmt::Assign { targets, expr, .. } => {
                    // A nested setArray call inside the RHS is the
                    // literal init (`A=(...)` lowers to `A=setArray(...)`).
                    // That init is NOT a whole-array reassignment — only a
                    // scalar (non-setArray) assign to the bare name is.
                    let init_of: HashSet<String> = {
                        let mut s = HashSet::new();
                        find_init_names(expr, &mut s);
                        s
                    };
                    find_setarray(expr, writes, assigns);
                    // `v = v+1` increment: record the active guard bound
                    // for the global-upper map.
                    if let IrExpr::Arith(x) = expr {
                        if let ArithAst::Bin { op, lhs, rhs } = x.as_ref() {
                            if op == "+" && matches!(rhs.as_ref(), ArithAst::Num(1)) {
                                for t in targets {
                                    if t.indices.is_empty() && !t.var.contains('[') {
                                        if let ArithAst::Var(w) | ArithAst::Ident(w) = lhs.as_ref()
                                        {
                                            if w == &t.var {
                                                if let Some(g) = guards.get(&t.var) {
                                                    if let Some(u) = g.upper {
                                                        inc_guards
                                                            .entry(t.var.clone())
                                                            .or_default()
                                                            .push(u);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    for t in targets {
                        if t.var.contains('[') {
                            let Some((base, kk)) = split_baked(&t.var) else {
                                continue;
                            };
                            if !is_ident(&base) {
                                continue;
                            }
                            let w = writes.entry(base).or_default();
                            w.store_vals.push(expr.clone());
                            match baked_key(&kk) {
                                Some(Key::Const(i)) => w.const_keys.push(i),
                                Some(Key::Var(v)) => {
                                    let g = guards.get(&v).cloned();
                                    w.dyn_keys.push((v, g));
                                }
                                Some(Key::Other) | None => w.other_key = true,
                            }
                        } else if is_ident(&t.var) && !init_of.contains(&t.var) {
                            writes.entry(t.var.clone()).or_default().reassign = true;
                        }
                    }
                }
                IrStmt::If {
                    cond,
                    then,
                    elsifs,
                    else_,
                    ..
                } => {
                    let mut g = guards.clone();
                    merge_guard(cond, &mut g);
                    walk(then, writes, &g, assigns, inc_guards);
                    for (c, b) in elsifs {
                        let mut g2 = guards.clone();
                        merge_guard(c, &mut g2);
                        walk(b, writes, &g2, assigns, inc_guards);
                    }
                    walk(else_, writes, guards, assigns, inc_guards);
                }
                IrStmt::While { cond, body, .. } | IrStmt::DoWhile { cond, body, .. } => {
                    let mut g = guards.clone();
                    merge_guard(cond, &mut g);
                    walk(body, writes, &g, assigns, inc_guards);
                }
                IrStmt::For { body, .. }
                | IrStmt::Block(body)
                | IrStmt::Subshell(body)
                | IrStmt::Background(body) => walk(body, writes, guards, assigns, inc_guards),
                IrStmt::ForInit {
                    init, step, body, ..
                } => {
                    walk(init, writes, guards, assigns, inc_guards);
                    walk(step, writes, guards, assigns, inc_guards);
                    walk(body, writes, guards, assigns, inc_guards);
                }
                IrStmt::Function {
                    body, named_blocks, ..
                } => {
                    walk(body, writes, guards, assigns, inc_guards);
                    for (_, b) in named_blocks {
                        walk(b, writes, guards, assigns, inc_guards);
                    }
                }
                IrStmt::Try {
                    body,
                    excepts,
                    else_body,
                    finally_body,
                    ..
                } => {
                    walk(body, writes, guards, assigns, inc_guards);
                    for e in excepts {
                        walk(&e.body, writes, guards, assigns, inc_guards);
                    }
                    walk(else_body, writes, guards, assigns, inc_guards);
                    walk(finally_body, writes, guards, assigns, inc_guards);
                }
                IrStmt::Case { clauses, .. } => {
                    for c in clauses {
                        walk(&c.body, writes, guards, assigns, inc_guards);
                    }
                }
                IrStmt::Select { clauses } => {
                    for c in clauses {
                        walk(&c.body, writes, guards, assigns, inc_guards);
                    }
                }
                IrStmt::Redirect { inner, .. } => walk(inner, writes, guards, assigns, inc_guards),
                IrStmt::Pipeline { stages, .. } => {
                    for st in stages {
                        walk(st, writes, guards, assigns, inc_guards);
                    }
                }
                IrStmt::Shaderize { body, .. } => walk(body, writes, guards, assigns, inc_guards),
                IrStmt::Expr(e) => find_setarray(e, writes, assigns),
                _ => {}
            }
        }
    }
    /// Names whose `setArray` init lives inside this RHS (`A=setArray(...)`
    /// assigned to `A` is the literal init, not a reassignment).
    fn find_init_names(e: &IrExpr, out: &mut HashSet<String>) {
        if let IrExpr::Call { func, args } = e {
            if func == "setArray" {
                if let Some(n) = str_arg(args, 0) {
                    out.insert(n);
                }
            }
            for a in args {
                find_init_names(a, out);
            }
        }
    }
    fn find_setarray(
        e: &IrExpr,
        writes: &mut HashMap<String, W>,
        assigns: &HashMap<String, Assigns>,
    ) {
        match e {
            IrExpr::Call { func, args } if func == "setArray" => {
                if let Some(n) = str_arg(args, 0) {
                    let w = writes.entry(n).or_default();
                    w.setarrays += 1;
                    if let Some(E::Array(items)) = args.get(1) {
                        if w.lit.is_none() {
                            w.lit = Some(items.clone());
                        }
                    }
                }
            }
            IrExpr::Call { func, args } if func == "setArrayAppend" => {
                if let Some(n) = str_arg(args, 0) {
                    writes.entry(n).or_default().append = true;
                }
            }
            IrExpr::Call { func, args } if func == "builtin" || func == "exec" => {
                if matches!(str_arg(args, 0).as_deref(), Some("unset")) {
                    for a in args.iter().skip(1) {
                        if let E::Str(n, _) = a {
                            writes.entry(n.clone()).or_default().unset = true;
                        }
                    }
                }
                for a in args {
                    find_setarray(a, writes, assigns);
                }
            }
            IrExpr::Call { args, .. } => {
                for a in args {
                    find_setarray(a, writes, assigns);
                }
            }
            IrExpr::Array(items) => {
                for a in items {
                    find_setarray(a, writes, assigns);
                }
            }
            IrExpr::Arrow(stmts) => {
                let mut ig = HashMap::new();
                walk(stmts, writes, &HashMap::new(), assigns, &mut ig)
            }
            _ => {}
        }
    }
    /// Key shapes for baked `A[k]` targets.
    enum Key {
        Const(i64),
        Var(String),
        Other,
    }
    /// Classify a baked key: decimal constant, `$var`/`${var}`, else Other.
    fn baked_key(k: &str) -> Option<Key> {
        let t = k.trim().trim_matches('"');
        if let Ok(i) = t.parse::<i64>() {
            return Some(Key::Const(i));
        }
        let v = t
            .trim_start_matches('$')
            .trim_start_matches('{')
            .trim_end_matches('}');
        if is_ident(v) {
            return Some(Key::Var(v.to_string()));
        }
        Some(Key::Other)
    }
    /// A store RHS is int-domain under the CURRENT scalar membership:
    /// `Arith`/`Int`/canonical text always; `Var`/`getVar` when the
    /// source is a member (cycle-guarded through the assigns map, like
    /// the scalar leaf); `arrayIndex` over a currently-homed array.
    /// Called at verdict time (not walk time) so the joint fixpoint sees
    /// shrunken membership. `homed` is the previous round's array set
    /// (greatest-fixpoint: removal only shrinks).
    fn store_val_int(
        e: &IrExpr,
        scalars: &HashSet<String>,
        seeded: &HashSet<String>,
        assigns: &HashMap<String, Assigns>,
        homed: &HashSet<String>,
        visiting: &mut Vec<String>,
    ) -> bool {
        match e {
            IrExpr::Int(_) | IrExpr::Arith(_) => true,
            IrExpr::Str(s, _) => {
                let t = s.trim();
                !t.is_empty()
                    && t.strip_prefix('-')
                        .unwrap_or(t)
                        .bytes()
                        .all(|c| c.is_ascii_digit())
                    && !(t.len() > 1 && (t.starts_with('0') || t.starts_with("-0")))
                    && t.parse::<i64>().is_ok()
            }
            IrExpr::Var(n, _) | IrExpr::Ident(n) => {
                if matches!(n.as_str(), "?" | "#" | "!" | "$") {
                    return true;
                }
                if is_positional(n) {
                    return true;
                }
                if seeded.contains(n) {
                    return true;
                }
                if !scalars.contains(n) || visiting.contains(n) {
                    return false;
                }
                let Some(a) = assigns.get(n) else {
                    return false;
                };
                visiting.push(n.clone());
                let ok = a
                    .rhs
                    .iter()
                    .all(|x| store_val_int(x, scalars, seeded, assigns, homed, visiting));
                visiting.pop();
                ok
            }
            IrExpr::Call { func, args } if func == "getVar" => match str_arg(args, 0).as_deref() {
                Some(n) => {
                    if matches!(n, "?" | "#" | "!" | "$") {
                        return true;
                    }
                    if is_positional(&n) {
                        return true;
                    }
                    if seeded.contains(n) {
                        return true;
                    }
                    if !scalars.contains(n) || visiting.contains(&n.to_string()) {
                        return false;
                    }
                    let Some(a) = assigns.get(n) else {
                        return false;
                    };
                    visiting.push(n.to_string());
                    let ok = a
                        .rhs
                        .iter()
                        .all(|x| store_val_int(x, scalars, seeded, assigns, homed, visiting));
                    visiting.pop();
                    ok
                }
                None => false,
            },
            IrExpr::Call { func, args } if func == "arrayIndex" => {
                matches!(str_arg(args, 0).as_deref(), Some(n) if homed.contains(n))
            }
            _ => false,
        }
    }
    /// A guard entry: (constant upper bound, proven `-ge 0`, var upper bound).
    ///
    /// Var bounds (`[ $e -lt $np ]`) resolve transitively through the
    /// global upper-bound map (mirror of the backend's `guard_bound`
    /// transitivity: `$e -lt $np` takes np's bound).
    #[derive(Clone, Default)]
    struct Guard {
        upper: Option<i64>,
        nonneg: bool,
        var_upper: Option<String>,
    }
    /// Merge a `test` condition's `$v -lt N` / `$v -lt $w` bounds into the guard set.
    fn merge_guard(cond: &IrExpr, g: &mut HashMap<String, Guard>) {
        fn texts(e: &IrExpr, out: &mut Vec<String>) {
            match e {
                IrExpr::Call { func, args } if func == "test" => {
                    for a in args {
                        if let IrExpr::Str(t, _) = a {
                            out.push(t.clone());
                        }
                    }
                }
                IrExpr::Call { args, .. } => {
                    for a in args {
                        texts(a, out);
                    }
                }
                _ => {}
            }
        }
        let mut ts = Vec::new();
        texts(cond, &mut ts);
        for t in &ts {
            for v in test_vars(t) {
                let mut upper: Option<i64> = None;
                let mut vup: Option<String> = None;
                let toks: Vec<&str> = t.split_whitespace().collect();
                let mut i = 0;
                while i < toks.len() {
                    let tk = toks[i];
                    let is_ref = tk == format!("${}", v)
                        || tk == format!("${{{}}}", v)
                        || tk.trim_matches('"') == format!("${}", v).as_str()
                        || tk.trim_matches('"') == format!("${{{}}}", v).as_str()
                        || tk == v;
                    if is_ref {
                        let op = toks.get(i + 1).copied().unwrap_or("");
                        let rhs = toks.get(i + 2).copied().unwrap_or("");
                        if let Ok(n) = rhs.trim_matches('"').parse::<i64>() {
                            match op {
                                "-lt" | "<" => upper = Some(upper.map_or(n, |u: i64| u.min(n))),
                                "-le" | "<=" => {
                                    upper = Some(upper.map_or(n + 1, |u: i64| u.min(n + 1)))
                                }
                                "-ge" | ">=" => {
                                    if n <= 0 {
                                        g.entry(v.clone()).or_default().nonneg = true;
                                    }
                                }
                                "-gt" | ">" => {
                                    if n < 0 {
                                        g.entry(v.clone()).or_default().nonneg = true;
                                    }
                                }
                                _ => {}
                            }
                        } else if op == "-lt" || op == "<" {
                            // Transitive var bound (`$e -lt $np`): resolved
                            // through the global upper-bound map at verdict
                            // time (mirror of `guard_bound`).
                            let w = rhs
                                .trim_matches('"')
                                .trim_start_matches('$')
                                .trim_start_matches('{')
                                .trim_end_matches('}');
                            if is_ident(w) {
                                vup = Some(w.to_string());
                            }
                        }
                    }
                    i += 1;
                }
                if upper.is_some() || vup.is_some() {
                    let e = g.entry(v.clone()).or_default();
                    if let Some(nu) = upper {
                        e.upper = Some(e.upper.map_or(nu, |x: i64| x.min(nu)));
                    }
                    if vup.is_some() {
                        e.var_upper = vup;
                    }
                }
            }
        }
    }
    /// `$var` refs inside a test text.
    fn test_vars(t: &str) -> Vec<String> {
        let (refs, _) = test_refs(t);
        refs
    }
    let g0: HashMap<String, Guard> = HashMap::new();
    // Scalar assigns map for the store-value check (collected once).
    let mut sax: HashMap<String, Assigns> = HashMap::new();
    collect_assigns(&prog.stmts, &mut sax, false);
    for sub in &prog.subs {
        collect_assigns(&sub.body, &mut sax, false);
    }
    let mut inc_guards: HashMap<String, Vec<i64>> = HashMap::new();
    walk(&prog.stmts, &mut writes, &g0, &sax, &mut inc_guards);
    for sub in &prog.subs {
        walk(&sub.body, &mut writes, &g0, &sax, &mut inc_guards);
    }
    // Global upper bounds for the transitive guard step (mirror of the
    // backend's `global_upper` + `guard_at_increments`): bound(v) = max
    // over const inits and the tightest `<N` guard enclosing any `v =
    // v+1` increment, with plain copies resolving transitively. The
    // increment-guard pairs are recorded by the statement walk below
    // (which already threads the guard set); copies resolve here.
    fn global_upper(
        assigns: &HashMap<String, Assigns>,
        inc_guards: &HashMap<String, Vec<i64>>,
    ) -> HashMap<String, i64> {
        fn bound_of(
            v: &str,
            assigns: &HashMap<String, Assigns>,
            inc_guards: &HashMap<String, Vec<i64>>,
            visiting: &mut Vec<String>,
        ) -> Option<i64> {
            if visiting.contains(&v.to_string()) {
                return None;
            }
            visiting.push(v.to_string());
            let result = (|| {
                let a = assigns.get(v)?;
                if a.rhs.is_empty() || a.in_copy {
                    return None;
                }
                let mut bound: Option<i64> = None;
                for e in &a.rhs {
                    match e {
                        IrExpr::Int(i) => {
                            if *i < 0 {
                                return None;
                            }
                            bound = Some(bound.map_or(*i, |m: i64| m.max(*i)));
                        }
                        IrExpr::Str(s, _) => match s.trim().parse::<i64>() {
                            Ok(i) if i >= 0 => {
                                bound = Some(bound.map_or(i, |m: i64| m.max(i)));
                            }
                            _ => return None,
                        },
                        IrExpr::Arith(x) => match x.as_ref() {
                            ArithAst::Bin { op, lhs, rhs }
                                if op == "+"
                                    && matches!(rhs.as_ref(), ArithAst::Num(1))
                                    && matches!(lhs.as_ref(), ArithAst::Var(w) | ArithAst::Ident(w) if w == v) =>
                            {
                                // Tightest guard over this var's
                                // increments (None = unguarded -> no bound).
                                let g =
                                    inc_guards.get(v).and_then(|gs| gs.iter().min().copied())?;
                                bound = Some(bound.map_or(g, |m: i64| m.max(g)));
                            }
                            _ => return None,
                        },
                        IrExpr::Var(w, _) | IrExpr::Ident(w) => {
                            match bound_of(w, assigns, inc_guards, visiting) {
                                Some(n) => {
                                    bound = Some(bound.map_or(n, |m: i64| m.max(n)));
                                }
                                None => return None,
                            }
                        }
                        IrExpr::Call { func, args } if func == "getVar" => {
                            match str_arg(args, 0).as_deref() {
                                Some(w) => match bound_of(w, assigns, inc_guards, visiting) {
                                    Some(n) => {
                                        bound = Some(bound.map_or(n, |m: i64| m.max(n)));
                                    }
                                    None => return None,
                                },
                                None => return None,
                            }
                        }
                        _ => return None,
                    }
                }
                bound
            })();
            visiting.pop();
            result
        }
        let mut out = HashMap::new();
        for v in assigns.keys() {
            if let Some(n) = bound_of(v, assigns, inc_guards, &mut Vec::new()) {
                out.insert(v.clone(), n);
            }
        }
        out
    }
    // Non-negativity for dynamic keys: zero-init plus only `+1`
    // increments, plus plain copies of proven-nonneg vars (the backend's
    // `proven_nonneg`, cycle-guarded).
    fn proven_nonneg(var: &str, assigns: &HashMap<String, Assigns>) -> bool {
        fn go(var: &str, assigns: &HashMap<String, Assigns>, visiting: &mut Vec<String>) -> bool {
            if visiting.contains(&var.to_string()) {
                return false;
            }
            let Some(a) = assigns.get(var) else {
                return false;
            };
            if a.rhs.is_empty() {
                return false;
            }
            visiting.push(var.to_string());
            let ok = a.rhs.iter().all(|e| match e {
                IrExpr::Int(i) => *i >= 0,
                IrExpr::Str(s, _) => matches!(s.trim().parse::<i64>(), Ok(n) if n >= 0),
                IrExpr::Arith(x) => match x.as_ref() {
                    ArithAst::Bin { op, lhs, rhs }
                        if op == "+" && matches!(rhs.as_ref(), ArithAst::Num(1)) =>
                    {
                        matches!(lhs.as_ref(), ArithAst::Var(v) | ArithAst::Ident(v) if v == var)
                    }
                    ArithAst::Var(v) | ArithAst::Ident(v) => v == var,
                    _ => false,
                },
                IrExpr::Var(w, _) | IrExpr::Ident(w) => w == var || go(w, assigns, visiting),
                IrExpr::Call { func, args } if func == "getVar" => {
                    match str_arg(args, 0).as_deref() {
                        Some(w) => w == var || go(w, assigns, visiting),
                        None => false,
                    }
                }
                _ => false,
            });
            visiting.pop();
            ok
        }
        go(var, assigns, &mut Vec::new())
    }
    let dbg = std::env::var("SH2_DEBUG_INT_CYCLES").as_deref() == Ok("2");
    // Global upper bounds: var <= N when every init is a const <= N and
    // every `v = v+1` increment sits under an enclosing `<N` guard (the
    // cursor-counter shape), with plain copies resolving transitively
    // (mirror of the backend's `global_upper`; only what the transitive
    // guard step needs).
    let gupper = global_upper(&sax, &inc_guards);
    // Bound of a guard entry: the constant upper, else the transitive
    // var bound (`$e -lt $np` takes np's global bound).
    fn guard_bound(g: Option<&Guard>, gupper: &HashMap<String, i64>) -> Option<i64> {
        let g = g?;
        if let Some(u) = g.upper {
            return Some(u);
        }
        if let Some(w) = &g.var_upper {
            return gupper.get(w).copied();
        }
        None
    }
    let mut eligible: HashSet<String> = HashSet::new();
    for (arr, w) in &writes {
        if dbg && (arr.starts_with("RB_") || arr.starts_with("CUBE") || arr == "FACE_N") {
            eprintln!(
                "INT_CYCLES arr {arr}: setarrays={} lit={} append={} reassign={} unset={} other={} nconst={} ndyn={}",
                w.setarrays,
                w.lit.as_ref().map(|l| l.len()).unwrap_or(999),
                w.append,
                w.reassign,
                w.unset,
                w.other_key,
                w.const_keys.len(),
                w.dyn_keys.len(),
            );
        }
        if w.setarrays != 1 || w.lit.is_none() {
            continue;
        }
        if w.append || w.reassign || w.unset || w.other_key {
            continue;
        }
        if str_read.contains(arr) || iterated.contains(arr) {
            continue;
        }
        let elems = w.lit.as_ref().unwrap();
        if elems.is_empty() || !elems.iter().all(elem_int) {
            continue;
        }
        let n = elems.len() as i64;
        // Constant keys satisfy 0 <= k < N.
        if w.const_keys.iter().any(|&k| k < 0 || k >= n) {
            continue;
        }
        // Class F (full-cover fixed arrays, mirrors the backend): a
        // `$var` dynamic key needs no guard/nonneg proof. The literal
        // cover fills every slot so no holes can form; fixed-array
        // stores render the exact `_sh_arr_set` guard in both
        // representations (negative stores nothing, past-cap exits
        // 127), and reads render the len guard per context (`""` for
        // string observers, `0` for numeric ones). The guard calls
        // below stay so SH2_DEBUG_INT_CYCLES=2 keeps reporting what
        // the old rule would have rejected.
        for (k, g) in &w.dyn_keys {
            let covered = guard_bound(g.as_ref(), &gupper).is_some_and(|u| u <= n);
            let nn = proven_nonneg(k, &sax);
            if dbg && (!covered || !nn) {
                eprintln!("INT_CYCLES guard-accepted {arr}[{k}] n={n}");
            }
        }
        // Class A (append-only) is subsumed: no indexed stores were
        // recorded (dyn/const/other all empty) — the literal cover plus
        // append-only growth is dense by construction.
        eligible.insert(arr.clone());
    }
    // Greatest fixpoint over store values (mirror of the backend's
    // intwrites fixpoint): assume all eligible, drop violators.
    // `arrayIndex(B)` leaves need B homed — mutually recursive for
    // copyback pairs (`RB_PX[$e] = RB_QX[$e]` circulates values, so
    // both hold). The bootstrap round (!strict_stores) skips the
    // store-value check so scalar/array cycles can seed each other.
    let mut out = eligible;
    if strict_stores {
        loop {
            let mut toss: Vec<String> = Vec::new();
            for arr in out.iter() {
                let w = &writes[arr];
                if !w
                    .store_vals
                    .iter()
                    .all(|e| store_val_int(e, scalars, seeded, assigns, &out, &mut Vec::new()))
                {
                    toss.push(arr.clone());
                }
            }
            if toss.is_empty() {
                break;
            }
            for a in toss {
                out.remove(&a);
            }
        }
    }
    out
}
/// Int-domain literal element: `Arith`/`Int` nodes and canonical-numeric
/// text (same strict rule as the scalar leaf — no leading zeros).
fn elem_int(e: &IrExpr) -> bool {
    match e {
        IrExpr::Int(_) | IrExpr::Arith(_) => true,
        IrExpr::Str(s, _) => {
            let t = s.trim();
            !t.is_empty()
                && t.strip_prefix('-')
                    .unwrap_or(t)
                    .bytes()
                    .all(|c| c.is_ascii_digit())
                && !(t.len() > 1 && (t.starts_with('0') || t.starts_with("-0")))
                && t.parse::<i64>().is_ok()
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn prog_of(src: &str) -> IrProgram {
        debashl::transforms::set_target(Some("c"));
        let a1 = otranspilerl::shell_to_shir(src);
        debashl::shir_json_in::shir_json_to_ir(&a1).expect("ingress")
    }

    #[test]
    fn swap_cycle_homes_int() {
        // The rb_tri shape: corners from a literal table, permuted
        // through a temp. All three must home Int.
        let mut p = prog_of(
            "#!/bin/bash\nT=(0 0 0 0 0 0 0 0)\nfx() {\n  x0=${T[0]}\n  x1=${T[1]}\n  x2=${T[2]}\n  t=$x1; x1=$x2; x2=$t\n  y=$((x1 + x2))\n  if [ \"$y\" -lt 10 ]; then echo done; fi\n}\nfx\n",
        );
        assert!(seed_int_cycles(&mut p));
        let vt: HashMap<String, debashl::ir::IrType> = p.var_types.iter().cloned().collect();
        for v in ["x0", "x1", "x2", "t", "y"] {
            assert_eq!(vt.get(v), Some(&debashl::ir::IrType::Int), "want Int: {v}");
        }
    }

    #[test]
    fn hex_and_row_text_stays_str() {
        // Non-canonical text is never proposed, even beside int mixes.
        let mut p = prog_of(
            "#!/bin/bash\nT=(0 0 0 0)\nfx() {\n  h=${T[0]}\n  h=\"00ff\" \n  r=\"row: $h\"\n  echo \"$r\"\n}\nfx\n",
        );
        seed_int_cycles(&mut p);
        let vt: HashMap<String, debashl::ir::IrType> = p.var_types.iter().cloned().collect();
        assert_ne!(vt.get("h"), Some(&debashl::ir::IrType::Int));
        assert_ne!(vt.get("r"), Some(&debashl::ir::IrType::Int));
    }

    #[test]
    fn echoed_var_is_excluded() {
        // A directly string-observed var is excluded from the push even
        // when every assign is numeric (the str_use gate). Note the pass
        // only ADDS verdicts — the core's own Int for `n` (if any) is
        // demote's business, so the test uses hex text the core leaves
        // Str and asserts the pass adds nothing for it.
        let mut p = prog_of("#!/bin/bash\nfx() {\n  h=\"00ff\"\n  echo \"val=$h\"\n}\nfx\n");
        let before = p.var_types.len();
        seed_int_cycles(&mut p);
        let vt: HashMap<String, debashl::ir::IrType> = p.var_types.iter().cloned().collect();
        assert_ne!(vt.get("h"), Some(&debashl::ir::IrType::Int));
        assert_eq!(p.var_types.len(), before);
    }

    #[test]
    fn kill_switch_disables() {
        std::env::set_var("SH2_NO_INT_CYCLES", "1");
        let mut p = prog_of("#!/bin/bash\nfx() {\n  a=$((1))\n  b=$a\n}\nfx\n");
        assert!(!seed_int_cycles(&mut p));
        std::env::remove_var("SH2_NO_INT_CYCLES");
    }
}
