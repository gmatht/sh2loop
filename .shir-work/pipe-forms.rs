//! shir-pipe-forms — eliminate `system('bash', '-c', …)` shell-out call
//! sites by folding statement-position shapes the shIR Perl renderer has
//! no native arm for into the canonical NATIVE statement shapes both
//! backends already render in-process (no bash at runtime).
//!
//! ## Why
//!
//! `./fail-shir` counts `system('bash', …)` call sites in the rendered
//! Perl. Many remaining shell-outs are commands in the verified emulable
//! set (harness/shir-whitelist.txt) whose shell-out is an artefact of the
//! STATEMENT SHAPE, not of the command:
//!
//! 1. **Statement-position pipelines** (`echo ARGS | grep P`,
//!    `printf FMT | sort`, `echo X | tr S1 S2 | sort | head -N`, …): the
//!    Perl renderer rebuilds the shell text and runs the WHOLE pipeline
//!    via `bash -c` (pipeline_call_to_cmd). When the producer is a static
//!    `echo`/`printf` and every stage is a compile-time foldable
//!    line/byte filter, the pipeline's stdout + last-stage exit status
//!    are compile-time values: the whole thing collapses to a native
//!    `printf` exec (the output) + a `true`/`false` exec (grep's exit
//!    status). The ESTree renderer already handles the SAME static
//!    shapes natively (its runtime mini-grep/tr/head/tail/wc agree with
//!    bash — the corpus passes), so the A1 fold keeps estree output
//!    byte-identical while removing the bash dependency.
//!
//! 2. **`test && echo|printf` / `test || echo|printf` control chains**
//!    (single-arm): the Perl renderer's `control_chain_to_perl`
//!    if-guards the shell-out of the echo arm
//!    (`if (cond) { system('bash','-c', q{'echo' …}) }`). The native
//!    shape is the A1 `If` — both renderers already emit the test cond
//!    and the echo arm natively; the false path (no else) matches the
//!    stdout of the `&&`/`||` short-circuit exactly.
//!
//! 3. **`declare -A NAME` / `declare -a NAME`** (bare, no init): the
//!    Perl renderer shells out the `declare` builtin; the A1
//!    `DeclareArray` statement (in the contract — serialize + ingress +
//!    both renderers) is the native "create an empty (assoc|indexed)
//!    array" shape: no output, status 0, exactly bash's declaration.
//!
//! ## Soundness (REFUSE > GUESS)
//!
//! - A pipeline folds ONLY when producer + every stage are fully static
//!   (literal words — a `$var` read, a capture, an env word or a file
//!   operand REFUSES the whole pipeline) and ASCII (byte semantics; the
//!   byte-offset/word-boundary rules are C-locale ASCII).
//! - grep folds ONLY literal patterns: `-F` (any literal) or bre/ere
//!   patterns FREE of every regex metachar (`.*[]\^$()+?{}|`) → plain
//!   substring / whole-line / whole-word matching. Any real regex, `-o`,
//!   `-P`, `-e`, `-f`, `-l/-L`, `-Z/-z`, `-r`, `--color` or a file
//!   operand REFUSES (the transform never guesses at regex semantics).
//! - grep flags mirror the runtime's `grepSelect` exactly (v/i/x/w/n/b/
//!   c/m/q and the -A/-B/-C range merge with `--` group separators and
//!   `-n` `:`/`-` markers).
//! - tr folds only the fixed SET grammar (single chars, `a-z` ranges,
//!   `[:…:]` classes, `\n \t \\ \0` escapes) with `-s` squeeze / `-d`
//!   delete; complement `-c` and an unknown escape REFUSE.
//! - head/tail operate on the raw byte stream (GNU preserves the input
//!   line endings); sort folds only plain/-n/-r over `[0-9a-z .-]` lines
//!   (locale-independent byte order); wc folds -l/-w/-c/-L.
//! - A `Redirect{inner:[Expr(pipeline)]}` with a single fd-1 w/wc/a file
//!   target folds the inner into a Block (shir-native-stmt's
//!   file-redirect trick): the Perl native select fallback writes the
//!   folded output into the file; estree's redirect writes the Block's
//!   output through the fd-1 target. The file is truncated in every case
//!   (bash truncates even when grep prints nothing).
//! - The chain fold only fires for a PURE test chain (test calls joined
//!   by And/Or/Not — no commands in the guard) with a single
//!   always-success echo/printf arm; fallible arms and impure guards
//!   REFUSE.

use crate::ir::{BinOpKind, InterpPart, IrExpr, IrStmt, Sigil, StrStyle};

/// Apply the transform. Returns whether anything changed.
pub fn transform(stmts: &mut Vec<IrStmt>) -> bool {
    let mut c = false;
    for s in stmts.iter_mut() {
        c |= transform_stmt(s);
    }
    c
}

fn st(s: &str) -> IrExpr {
    IrExpr::Str(s.to_string(), StrStyle::DoubleQuoted)
}

/// A true/false status exec (native everywhere: Perl
/// `$main_exit_code = $CHILD_ERROR = 0|1;`, estree exec).
fn status_exec(ok: bool) -> IrStmt {
    IrStmt::Expr(IrExpr::Call {
        func: "exec".to_string(),
        args: vec![st(if ok { "true" } else { "false" }), IrExpr::Array(vec![])],
    })
}

/// `printf "%s\n" <text-minus-final-nl>` — native exec printing
/// `text` + one trailing newline (bash `printf '%s\n'` semantics; both
/// renderers render printf natively). The folded pipeline output ends in
/// a newline (every stage keeps it), so passing it minus the final \n
/// makes printf reproduce the bytes exactly.
fn output_exec(text: &str) -> IrStmt {
    IrStmt::Expr(IrExpr::Call {
        func: "exec".to_string(),
        args: vec![
            st("printf"),
            IrExpr::Array(vec![
                st("%s\n"),
                IrExpr::Str(text.to_string(), StrStyle::DoubleQuoted),
            ]),
        ],
    })
}

fn transform_stmt(st: &mut IrStmt) -> bool {
    // Recurse into children FIRST (bottom-up).
    let mut c = match st {
        IrStmt::If {
            cond,
            then,
            elsifs,
            else_,
        } => {
            let mut x = transform_expr(cond);
            x |= transform(then);
            for (ec, eb) in elsifs.iter_mut() {
                x |= transform_expr(ec);
                x |= transform(eb);
            }
            x |= transform(else_);
            x
        }
        IrStmt::For { iter, body, .. } => {
            let mut x = transform_expr(iter);
            x |= transform(body);
            x
        }
        IrStmt::While { cond, body, .. } => {
            let mut x = transform(body);
            x |= transform_expr(cond);
            x
        }
        IrStmt::DoWhile { body, cond, .. } => {
            let mut x = transform(body);
            x |= transform_expr(cond);
            x
        }
        IrStmt::Case {
            discriminant,
            clauses,
        } => {
            let mut x = transform_expr(discriminant);
            for cl in clauses.iter_mut() {
                x |= transform(&mut cl.body);
            }
            x
        }
        IrStmt::Block(b)
        | IrStmt::Subshell(b)
        | IrStmt::Background(b)
        | IrStmt::Function { body: b, .. } => transform(b),
        IrStmt::Pipeline { stages, .. } => {
            let mut x = false;
            for stg in stages.iter_mut() {
                x |= transform(stg);
            }
            x
        }
        IrStmt::Expr(e) => {
            let mut x = transform_expr(e);
            x |= chain_to_if(st);
            x |= pipeline_stmt(st);
            x
        }
        IrStmt::Assign { expr, .. } | IrStmt::Output { value: expr, .. } => transform_expr(expr),
        IrStmt::Declare {
            init: Some(expr), ..
        } => transform_expr(expr),
        IrStmt::WriteFile { path, content, .. } => transform_expr(path) | transform_expr(content),
        IrStmt::Redirect { inner, redirects } => {
            let mut x = transform(inner);
            for r in redirects.iter_mut() {
                x |= transform_expr(&mut r.target);
            }
            x |= pipeline_redirect(st);
            x
        }
        IrStmt::Exec {
            cmd, args, env, ..
        } => {
            let mut x = transform_expr(cmd);
            for a in args.iter_mut() {
                x |= transform_expr(a);
            }
            for (_, v) in env.iter_mut() {
                x |= transform_expr(v);
            }
            x |= declare_to_declare_array(st);
            x
        }
        _ => false,
    };
    c
}

fn transform_expr(e: &mut IrExpr) -> bool {
    match e {
        IrExpr::Arrow(stmts) => transform(stmts),
        IrExpr::Call { args, .. } => {
            let mut c = false;
            for a in args.iter_mut() {
                c |= transform_expr(a);
            }
            c
        }
        IrExpr::Array(items) => {
            let mut c = false;
            for a in items.iter_mut() {
                c |= transform_expr(a);
            }
            c
        }
        IrExpr::Object(pairs) => {
            let mut c = false;
            for (_, v) in pairs.iter_mut() {
                c |= transform_expr(v);
            }
            c
        }
        IrExpr::BinOp { lhs, rhs, .. } => transform_expr(lhs) | transform_expr(rhs),
        IrExpr::Index { key, .. } => transform_expr(key),
        _ => false,
    }
}

/// The words of a canonical command Call (`exec`/`builtin`): `(cmd,
/// Array(words))`.
fn exec_words(e: &IrExpr) -> Option<(&str, &[IrExpr])> {
    if let IrExpr::Call { func, args } = e {
        if matches!(func.as_str(), "exec" | "builtin") {
            if let [IrExpr::Str(cmd, _), IrExpr::Array(words)] = args.as_slice() {
                return Some((cmd, words));
            }
        }
    }
    None
}

/// A stage's single statement as a command Call (`Arrow([Expr(exec)])`).
fn stage_cmd(e: &IrExpr) -> Option<(&str, &[IrExpr])> {
    let IrExpr::Arrow(stmts) = e else {
        return None;
    };
    let [IrStmt::Expr(inner)] = stmts.as_slice() else {
        return None;
    };
    exec_words(inner)
}

/// The static (compile-time) text of a word expr: a Str or an
/// all-literals Interpolate. Any dynamic part → None.
fn word_static_text(e: &IrExpr) -> Option<String> {
    match e {
        IrExpr::Str(s, _) => Some(s.clone()),
        IrExpr::Interpolate(parts) => {
            let mut out = String::new();
            for p in parts {
                match p {
                    InterpPart::Lit(s) => out.push_str(s),
                    _ => return None,
                }
            }
            Some(out)
        }
        _ => None,
    }
}

// ── Family 2: statement-position pipeline → native Block ────────────

/// The `pipeline` Call's stage list (Arrows). Handles both
/// `pipeline([Arrow,…])` and `pipeline([Array([Arrow,…])])`.
fn pipeline_stages(e: &IrExpr) -> Option<Vec<&IrExpr>> {
    let IrExpr::Call { func, args } = e else {
        return None;
    };
    if func != "pipeline" {
        return None;
    }
    match args.as_slice() {
        [IrExpr::Array(stages)] => Some(stages.iter().collect()),
        other if other.iter().all(|a| matches!(a, IrExpr::Arrow(_))) => Some(other.to_vec()),
        _ => None,
    }
}

/// Fold a fully-static pipeline into its native Block. Returns the
/// statements (None → leave the pipeline alone).
fn fold_pipeline(stages: &[&IrExpr]) -> Option<Vec<IrStmt>> {
    let mut stages = stages.to_vec();
    if stages.is_empty() {
        return None;
    }
    let text = producer_text(stages[0])?;
    if !text.is_ascii() {
        return None;
    }
    let mut processed: Option<String> = Some(text);
    let mut ok = true;
    for s in &stages[1..] {
        let t = processed.take()?; // `process` must be available
        let (nt, nok) = stage_filter(&t, s)?;
        processed = Some(nt);
        ok = nok;
        if !processed.as_ref()?.is_ascii() {
            return None;
        }
    }
    let out = processed?;
    let mut blk: Vec<IrStmt> = Vec::new();
    if !out.is_empty() {
        // the pipeline output ends with a newline (every stage keeps the
        // trailing \n); pass it minus the final \n so printf re-outputs
        // the exact bytes.
        let body = out.strip_suffix('\n').unwrap_or(&out);
        blk.push(output_exec(body));
    }
    if !ok {
        // the last stage exited nonzero (grep found nothing). A failing
        // status exec prints nothing; `-c 0` prints its count first and
        // THEN records the nonzero status.
        blk.push(status_exec(false));
    }
    if blk.is_empty() {
        // status 0 with no output (unreachable — an echo/printf producer
        // always writes) — be safe.
        blk.push(status_exec(true));
    }
    Some(blk)
}

#[allow(clippy::ptr_arg)]
fn apply_block_to_stmt(st: &mut IrStmt, blk: Vec<IrStmt>) {
    if blk.len() == 1 {
        *st = blk.into_iter().next().unwrap();
    } else {
        *st = IrStmt::Block(blk);
    }
}

/// `IrStmt::Expr(pipeline([Arrow,…]))` → the folded native Block.
fn pipeline_stmt(st: &mut IrStmt) -> bool {
    let IrStmt::Expr(e) = st else {
        return false;
    };
    let stages = match pipeline_stages(e) {
        Some(s) => s,
        None => return false,
    };
    match fold_pipeline(&stages) {
        Some(blk) => {
            apply_block_to_stmt(st, blk);
            true
        }
        None => false,
    }
}

/// `Redirect{inner:[Expr(pipeline)], fd1 w/wc/a file}` → inner becomes a
/// Block of the folded statements (the native select-based file redirect
/// then writes them to the file).
fn pipeline_redirect(st: &mut IrStmt) -> bool {
    let IrStmt::Redirect { inner, redirects } = st else {
        return false;
    };
    let [r] = redirects.as_slice() else {
        return false;
    };
    if r.fd.unwrap_or(1) != 1 {
        return false;
    }
    if !matches!(r.mode.as_str(), "w" | "wc" | "a") {
        return false;
    }
    let [IrStmt::Expr(pipeline_expr)] = inner.as_slice() else {
        return false;
    };
    let stages = match pipeline_stages(pipeline_expr) {
        Some(s) => s,
        None => return false,
    };
    match fold_pipeline(&stages) {
        Some(blk) => {
            inner[0] = IrStmt::Block(blk);
            true
        }
        None => false,
    }
}

/// Producer stage 0: a static `echo`/`printf` whose full stdout is
/// computed here (`echo` joins words with spaces + trailing newline
/// unless `-n`; `-e`/`-E` control backslash decoding; printf evaluates
/// the format). A `cat` producer reads runtime stdin — refuse.
fn producer_text(stage: &IrExpr) -> Option<String> {
    let (cmd, words) = stage_cmd(stage)?;
    match cmd {
        "echo" => echo_produce(words),
        "printf" => printf_produce(words),
        _ => None,
    }
}

fn echo_produce(words: &[IrExpr]) -> Option<String> {
    let mut words = words;
    let mut no_nl = false;
    let mut esc = false;
    loop {
        let Some(first) = words.first() else { break };
        let s = word_static_text(first)?;
        match s.as_str() {
            "-n" => {
                no_nl = true;
                words = &words[1..];
            }
            "-e" => {
                esc = true;
                words = &words[1..];
            }
            "-E" => {
                words = &words[1..];
            }
            "-en" | "-ne" => {
                esc = true;
                no_nl = true;
                words = &words[1..];
            }
            "-En" | "-nE" => {
                no_nl = true;
                words = &words[1..];
            }
            "-eE" | "-Ee" => {
                esc = true;
                words = &words[1..];
            }
            _ => break,
        }
    }
    let mut joined = String::new();
    for (i, w) in words.iter().enumerate() {
        if i > 0 {
            joined.push(' ');
        }
        joined.push_str(&word_static_text(w)?);
    }
    if esc {
        joined = unescape_echo(&joined)?;
    }
    Some(joined)
}

/// bash `echo -e` backslash decoding (the subset the corpus uses — an
/// unknown escape REFUSES: REFUSE > GUESS).
fn unescape_echo(s: &str) -> Option<String> {
    let mut out = String::new();
    let mut cs = s.chars();
    while let Some(c) = cs.next() {
        if c == '\\' {
            match cs.next()? {
                'n' => out.push('\n'),
                't' => out.push('\t'),
                'r' => out.push('\r'),
                '\\' => out.push('\\'),
                _ => return None,
            }
        } else {
            out.push(c);
        }
    }
    Some(out)
}

/// bash `printf FMT ARGS` producer: evaluates `\n \t \\ \r` and `%s %d
/// %c %%` conversions; leftover args (format cycling) REFUSE.
fn printf_produce(words: &[IrExpr]) -> Option<String> {
    if words.is_empty() {
        return None;
    }
    let fmt = word_static_text(&words[0])?;
    let args: Vec<String> = words[1..].iter().map(word_static_text).collect::<Option<_>>()?;
    let mut out = String::new();
    let mut ai = 0usize;
    let mut cs = fmt.chars();
    while let Some(c) = cs.next() {
        if c == '\\' {
            match cs.next()? {
                'n' => out.push('\n'),
                't' => out.push('\t'),
                'r' => out.push('\r'),
                '\\' => out.push('\\'),
                _ => return None,
            }
        } else if c == '%' {
            match cs.next()? {
                '%' => out.push('%'),
                's' => {
                    out.push_str(args.get(ai)?);
                    ai += 1;
                }
                'd' => {
                    let x: i64 = args.get(ai)?.parse().ok()?;
                    out.push_str(&x.to_string());
                    ai += 1;
                }
                'c' => {
                    out.push(args.get(ai)?.chars().next()?);
                    ai += 1;
                }
                _ => return None,
            }
        } else {
            out.push(c);
        }
    }
    if ai != args.len() {
        return None; // format cycling over leftover args — refuse
    }
    Some(out)
}

/// Apply one non-producer filter stage to the running text, returning
/// (new_text, exit_ok). None → the pipeline must be left alone.
fn stage_filter(text: &str, stage: &IrExpr) -> Option<(String, bool)> {
    let (cmd, words) = stage_cmd(stage)?;
    match cmd {
        // `cat` reading stdin is the identity filter.
        "cat" => {
            let ok = words.is_empty()
                || {
                    let [w] = words else {
                        return false;
                    };
                    word_static_text(w).as_deref() == Some("-")
                };
            if !ok {
                return None;
            }
            Some((text.to_string(), true))
        }
        "grep" => grep_filter(text, words),
        "tr" => Some((tr_apply(text, words)?, true)),
        "sort" => Some((sort_apply(text, words)?, true)),
        "head" => Some((head_apply(text, words)?, true)),
        "tail" => Some((tail_apply(text, words)?, true)),
        "wc" => Some((wc_apply(text, words)?, true)),
        _ => None,
    }
}

// ── grep filter (literal patterns only — mirrors the runtime) ─────────

struct GrepOpts {
    invert: bool,
    ignore_case: bool,
    fixed: bool,
    line_numbers: bool,
    byte_offsets: bool,
    count: bool,
    quiet: bool,
    max: usize,
    whole_line: bool,
    whole_word: bool,
    after: usize,
    before: usize,
}

fn line_matches(line: &str, pat: &str, o: &GrepOpts) -> bool {
    if !o.fixed && has_regex_meta(pat) {
        // a real regex — fold never reaches here
        return false;
    }
    let ci = o.ignore_case;
    if ci {
        let l = line.to_lowercase();
        let p = pat.to_lowercase();
        if o.whole_line {
            l == p
        } else if o.whole_word {
            contains_word(&l, &p)
        } else {
            l.contains(&p)
        }
    } else if o.whole_line {
        line == pat
    } else if o.whole_word {
        contains_word(line, pat)
    } else {
        line.contains(pat)
    }
}

fn has_regex_meta(pat: &str) -> bool {
    pat.chars().any(|c| {
        matches!(
            c,
            '.' | '*'
                | '['
                | ']'
                | '\\'
                | '^'
                | '$'
                | '('
                | ')'
                | '+'
                | '?'
                | '{'
                | '}'
                | '|'
        )
    })
}

fn is_word_char(c: char) -> bool {
    c.is_ascii_alphanumeric() || c == '_'
}

fn contains_word(line: &str, pat: &str) -> bool {
    if pat.is_empty() {
        return false;
    }
    let bytes: Vec<char> = line.chars().collect();
    let p: Vec<char> = pat.chars().collect();
    if p.len() > bytes.len() {
        return false;
    }
    for start in 0..=(bytes.len() - p.len()) {
        if bytes[start..].starts_with(&p[..]) {
            let before_ok = start == 0 || !is_word_char(bytes[start - 1]);
            let after_ok = start + p.len() >= bytes.len() || !is_word_char(bytes[start + p.len()]);
            if before_ok && after_ok {
                return true;
            }
        }
    }
    false
}

/// Parse the grep argv (words after `grep`): flags then ONE pattern.
/// Refuses any unsupported shape → the pipeline keeps its shell-out.
fn grep_filter(text: &str, words: &[IrExpr]) -> Option<(String, bool)> {
    let mut o = GrepOpts {
        invert: false,
        ignore_case: false,
        fixed: false,
        line_numbers: false,
        byte_offsets: false,
        count: false,
        quiet: false,
        max: usize::MAX,
        whole_line: false,
        whole_word: false,
        after: 0,
        before: 0,
    };
    let mut pattern: Option<String> = None;
    let mut i = 0usize;
    while i < words.len() {
        let w = word_static_text(&words[i])?;
        if w.starts_with('-') && !pattern.is_some() {
            if w == "--" {
                i += 1;
                continue;
            }
            if matches!(w.as_str(), "-A" | "-B" | "-C" | "-m") {
                let v: usize = word_static_text(&words[i + 1])?.parse().ok()?;
                match w.as_str() {
                    "-A" => o.after = v,
                    "-B" => o.before = v,
                    "-C" => {
                        o.after = v;
                        o.before = v;
                    }
                    _ => o.max = v,
                }
                i += 2;
                continue;
            }
            match w.as_str() {
                "-i" => o.ignore_case = true,
                "-F" => o.fixed = true,
                "-E" => {} // ERE — folded only when the pattern is literal
                "-e" => {
                    pattern = Some(word_static_text(&words[i + 1])?);
                    i += 2;
                    continue;
                }
                "-v" => o.invert = true,
                "-n" => o.line_numbers = true,
                "-b" => o.byte_offsets = true,
                "-c" => o.count = true,
                "-q" => o.quiet = true,
                "-x" => o.whole_line = true,
                "-w" => o.whole_word = true,
                _ => {
                    let body = &w[1..];
                    // combined shorts (`-vi`, `-nc`, …) — the foldable subset
                    if !body.is_empty()
                        && body
                            .chars()
                            .all(|c| matches!(c, 'v' | 'i' | 'n' | 'c' | 'q' | 'x' | 'w' | 'b'))
                    {
                        if body.contains('v') {
                            o.invert = true;
                        }
                        if body.contains('i') {
                            o.ignore_case = true;
                        }
                        if body.contains('n') {
                            o.line_numbers = true;
                        }
                        if body.contains('c') {
                            o.count = true;
                        }
                        if body.contains('q') {
                            o.quiet = true;
                        }
                        if body.contains('x') {
                            o.whole_line = true;
                        }
                        if body.contains('b') {
                            o.byte_offsets = true;
                        }
                        if body.contains('w') {
                            o.whole_word = true;
                        }
                    } else {
                        // any unsupported flag (o P l L Z z r H h --color -f …)
                        return None;
                    }
                }
            }
            i += 1;
            continue;
        }
        // the pattern (first positional after the flags)
        if pattern.is_some() {
            return None; // a second positional = a FILE operand — refuse
        }
        pattern = Some(w);
        i += 1;
    }
    let pattern = match pattern {
        Some(p) => p,
        None => return None, // no pattern — grep errors; refuse
    };
    if !o.fixed && has_regex_meta(&pattern) {
        return None; // a real regex — never fold
    }
    let (out, selected) = grep_select(text, &pattern, &o);
    Some((out, selected > 0))
}

/// The line-selection core — mirrors the runtime's `grepSelect` for the
/// literal-matched subset (linear byte offsets, ASCII).
fn grep_select(text: &str, pat: &str, o: &GrepOpts) -> (String, usize) {
    let s = text;
    if s.is_empty() {
        if o.count && !o.quiet {
            return ("0\n".to_string(), 0);
        }
        return (String::new(), 0);
    }
    let mut lines: Vec<&str> = s.split('\n').collect();
    if s.ends_with('\n') {
        lines.pop();
    }
    let line_sel = |line: &str| -> bool {
        let m = line_matches(line, pat, o);
        if o.invert {
            !m
        } else {
            m
        }
    };
    let mut out = String::new();
    let mut selected = 0usize;
    if o.quiet {
        for line in lines {
            if !line_sel(line) {
                continue;
            }
            selected += 1;
            if selected >= o.max {
                break;
            }
        }
        return (out, selected);
    }
    if o.count {
        let mut n = 0usize;
        for line in lines {
            if !line_sel(line) {
                continue;
            }
            selected += 1;
            n += 1;
            if selected >= o.max {
                break;
            }
        }
        out.push_str(&n.to_string());
        out.push('\n');
        return (out, selected);
    }
    if o.after == 0 && o.before == 0 {
        let mut offset = 0usize;
        for (li, line) in lines.iter().enumerate() {
            if !line_sel(line) {
                offset += line.len() + 1;
                continue;
            }
            selected += 1;
            if o.line_numbers {
                out.push_str(&format!("{}:", li + 1));
            }
            if o.byte_offsets {
                out.push_str(&format!("{}:", offset));
            }
            out.push_str(line);
            out.push('\n');
            offset += line.len() + 1;
            if selected >= o.max {
                break;
            }
        }
        return (out, selected);
    }
    // -A/-B/-C: merge overlapping/adjacent ranges, `--` between disjoint
    // groups; -n context lines carry `-`, selected lines `:` (GNU).
    let sel: Vec<bool> = lines.iter().map(|l| line_sel(l)).collect();
    let mut ranges: Vec<(usize, usize)> = Vec::new();
    for li in 0..lines.len() {
        if !sel[li] {
            continue;
        }
        selected += 1;
        let lo = li.saturating_sub(o.before);
        let hi = (li + o.after).min(lines.len() - 1);
        if let Some(last) = ranges.last_mut() {
            if lo <= last.1 + 1 {
                last.1 = last.1.max(hi);
            } else {
                ranges.push((lo, hi));
            }
        } else {
            ranges.push((lo, hi));
        }
        if selected >= o.max {
            break;
        }
    }
    for (ri, (lo, hi)) in ranges.iter().enumerate() {
        if ri > 0 {
            out.push_str("--\n");
        }
        for li in *lo..=*hi {
            let marker = if o.line_numbers {
                format!("{}{}", li + 1, if sel[li] { ':' } else { '-' })
            } else {
                String::new()
            };
            out.push_str(&marker);
            if o.byte_offsets {
                let offset: usize = lines[..li].iter().map(|l| l.len() + 1).sum();
                out.push_str(&format!("{}:", offset));
            }
            out.push_str(lines[li]);
            out.push('\n');
        }
    }
    (out, selected)
}

// ── tr filter `tr -s|-d SET1 [SET2]` (fixed-set grammar) ──────────────

fn tr_set(s: &str) -> Option<Vec<char>> {
    let chars: Vec<char> = s.chars().collect();
    let mut out: Vec<char> = Vec::new();
    let mut i = 0usize;
    while i < chars.len() {
        let c = chars[i];
        if c == '\\' {
            let e = *chars.get(i + 1)?;
            match e {
                'n' => out.push('\n'),
                't' => out.push('\t'),
                'r' => out.push('\r'),
                '\\' => out.push('\\'),
                '0' => {
                    let mut v = 0u32;
                    let mut j = i + 1;
                    let mut digits = 0;
                    while j < chars.len() && digits < 3 && chars[j].is_ascii_digit() {
                        v = v * 8 + chars[j].to_digit(8)?;
                        j += 1;
                        digits += 1;
                    }
                    if digits == 0 {
                        return None;
                    }
                    out.push(char::from_u32(v)?);
                    i = j;
                    continue;
                }
                _ => return None,
            }
            i += 2;
            continue;
        }
        if c == '[' {
            if chars.get(i + 1).copied() == Some(':') {
                let rest = &s[i + 1..];
                let end = rest.find(":]")?;
                let name = &rest[1..end];
                let cls = class_chars(name)?;
                out.extend(cls);
                i += 1 + end + 2;
                continue;
            }
            out.push(c);
            i += 1;
            continue;
        }
        if c == '-' {
            // a leading/trailing `-` is literal; else a range
            match (out.last().copied(), chars.get(i + 1).copied()) {
                (Some(lo), Some(hi)) if lo != '-' && hi != '-' => {
                    out.pop();
                    let lo = lo as u32;
                    let hi = hi as u32;
                    if lo > hi {
                        return None;
                    }
                    for x in lo..=hi {
                        out.push(char::from_u32(x)?);
                    }
                    i += 2;
                    continue;
                }
                _ => {
                    out.push('-');
                    i += 1;
                    continue;
                }
            }
        }
        out.push(c);
        i += 1;
    }
    Some(out)
}

fn class_chars(name: &str) -> Option<Vec<char>> {
    let mut out: Vec<char> = Vec::new();
    match name {
        "lower" => out.extend('a'..='z'),
        "upper" => out.extend('A'..='Z'),
        "digit" => out.extend('0'..='9'),
        "alpha" => {
            out.extend('a'..='z');
            out.extend('A'..='Z');
        }
        "alnum" => {
            out.extend('a'..='z');
            out.extend('A'..='Z');
            out.extend('0'..='9');
        }
        _ => return None,
    }
    Some(out)
}

fn tr_apply(text: &str, words: &[IrExpr]) -> Option<String> {
    let mut i = 0usize;
    let mut squeeze = false;
    let mut delete = false;
    loop {
        let Some(w) = words.get(i) else { return None };
        let s = word_static_text(w)?;
        match s.as_str() {
            "-s" => squeeze = true,
            "-d" => delete = true,
            "-c" | "-C" => return None, // complement — refuse
            _ => break,
        }
        i += 1;
    }
    let set1 = tr_set(&word_static_text(words.get(i)?)?)?;
    i += 1;
    let mut set2: Option<Vec<char>> = None;
    if !delete {
        set2 = Some(tr_set(&word_static_text(words.get(i)?)?)?);
        i += 1;
    }
    if i < words.len() {
        return None; // too many operands
    }
    let mut out = String::new();
    if delete {
        for c in text.chars() {
            if !set1.contains(&c) {
                out.push(c);
            }
        }
        return Some(out);
    }
    let set2 = match set2 {
        Some(s2) => s2,
        None => return None,
    };
    let pad = set2.last().copied()?;
    let mut prev_in_set1 = false;
    for c in text.chars() {
        let in1 = set1.contains(&c);
        if !in1 {
            out.push(c);
            prev_in_set1 = false;
            continue;
        }
        if squeeze && prev_in_set1 {
            continue; // collapse the run
        }
        let idx = set1.iter().position(|&x| x == c).unwrap_or(0);
        let t = set2.get(idx).copied().unwrap_or(pad);
        out.push(t);
        prev_in_set1 = true;
    }
    Some(out)
}

// ── sort / head / tail / wc filters ───────────────────────────────────

fn sort_apply(text: &str, words: &[IrExpr]) -> Option<String> {
    let mut numeric = false;
    let mut reverse = false;
    for w in words {
        let s = word_static_text(w)?;
        match s.as_str() {
            "-n" => numeric = true,
            "-r" => reverse = true,
            _ => return None, // other flags / file operands — refuse
        }
    }
    let mut lines: Vec<&str> = text.split('\n').collect();
    if text.ends_with('\n') {
        lines.pop();
    }
    if lines.is_empty() {
        return Some(String::new());
    }
    // locale-safety: fold only when every line sorts identically under
    // every locale (lowercase ASCII + digits + space/./-)
    if lines
        .iter()
        .any(|l| !l.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, ' ' | '.' | '-')))
    {
        return None;
    }
    let mut order: Vec<usize> = (0..lines.len()).collect();
    if numeric {
        order.sort_by(|&a, &b| {
            let na = lines[a].trim_start().parse::<i64>().ok().unwrap_or(0);
            let nb = lines[b].trim_start().parse::<i64>().ok().unwrap_or(0);
            na.cmp(&nb).then_with(|| lines[a].cmp(lines[b]))
        });
    } else {
        order.sort_by(|&a, &b| lines[a].cmp(lines[b]));
    }
    if reverse {
        order.reverse();
    }
    let mut out = String::new();
    for idx in order {
        out.push_str(lines[idx]);
        out.push('\n');
    }
    Some(out)
}

fn head_apply(text: &str, words: &[IrExpr]) -> Option<String> {
    let (mode, n) = parse_head_tail_args(words)?;
    match mode {
        b'l' => {
            if n == 0 {
                return Some(String::new());
            }
            let mut count = 0usize;
            for (i, b) in text.bytes().enumerate() {
                if b == b'\n' {
                    count += 1;
                    if count == n {
                        return Some(text[..=i].to_string());
                    }
                }
            }
            Some(text.to_string())
        }
        b'c' => Some(text.chars().take(n).collect()),
        _ => None,
    }
}

fn tail_apply(text: &str, words: &[IrExpr]) -> Option<String> {
    let (mode, n) = parse_head_tail_args(words)?;
    match mode {
        b'l' => {
            if text.is_empty() || n == 0 {
                return Some(String::new());
            }
            let nl: Vec<usize> = text
                .bytes()
                .enumerate()
                .filter(|(_, b)| *b == b'\n')
                .map(|(i, _)| i)
                .collect();
            if nl.len() < n {
                return Some(text.to_string());
            }
            let start = nl[nl.len() - n] + 1;
            Some(text[start..].to_string())
        }
        b'c' => {
            if n == 0 {
                return Some(String::new());
            }
            let len = text.chars().count();
            if len <= n {
                Some(text.to_string())
            } else {
                Some(text.chars().skip(len - n).collect())
            }
        }
        _ => None,
    }
}

/// `head -N` / `-n N` / `-c N` / `tail -N` / `-n N` / `-c N` — returns
/// (lines|chars, N).
fn parse_head_tail_args(words: &[IrExpr]) -> Option<(u8, usize)> {
    let mut n: Option<usize> = None;
    let mut mode: u8 = b'l';
    let mut i = 0usize;
    while let Some(w) = words.get(i) {
        let s = word_static_text(w)?;
        if let Some(rest) = s.strip_prefix("-c") {
            mode = b'c';
            n = Some(if rest.is_empty() {
                let v = word_static_text(words.get(i + 1)?)?;
                i += 2;
                v.parse().ok()?
            } else {
                i += 1;
                rest.parse().ok()?
            });
            continue;
        }
        if let Some(rest) = s.strip_prefix("-n") {
            mode = b'l';
            n = Some(if rest.is_empty() {
                let v = word_static_text(words.get(i + 1)?)?;
                i += 2;
                v.parse().ok()?
            } else {
                i += 1;
                rest.parse().ok()?
            });
            continue;
        }
        if let Some(rest) = s.strip_prefix('-') {
            n = Some(rest.parse().ok()?);
            i += 1;
            continue;
        }
        return None; // a file operand — refuse
    }
    Some((mode, n.unwrap_or(10)))
}

fn wc_apply(text: &str, words: &[IrExpr]) -> Option<String> {
    let mut flag: Option<char> = None;
    for w in words {
        let s = word_static_text(w)?;
        match s.as_str() {
            "-l" | "-w" | "-c" | "-L" => {
                if flag.is_some() {
                    return None; // multi-flag wc — refuse
                }
                flag = Some(s.chars().nth(1)?);
            }
            _ => return None, // a file operand — refuse (stdin only)
        }
    }
    let v: usize = match flag.unwrap_or('l') {
        'l' => text.bytes().filter(|&b| b == b'\n').count(),
        'c' => text.len(),
        'w' => text.split_whitespace().count(),
        'L' => {
            let body = text.strip_suffix('\n').unwrap_or(text);
            body.split('\n').map(|l| l.len()).max().unwrap_or(0)
        }
        _ => return None,
    };
    Some(format!("{}\n", v))
}

// ── Family 1: `test && echo` / `test || echo` → native If ─────────────

fn is_test_call(e: &IrExpr) -> bool {
    matches!(e, IrExpr::Call { func, .. } if func == "test")
}

/// A PURE test chain — `test` calls joined only by And/Or/Not.
fn is_pure_test(e: &IrExpr) -> bool {
    match e {
        IrExpr::Call { func, .. } => func == "test",
        IrExpr::BinOp { op, lhs, rhs } => match op {
            BinOpKind::And | BinOpKind::Or => is_pure_test(lhs) && is_pure_test(rhs),
            BinOpKind::Not => is_pure_test(lhs),
            _ => false,
        },
        _ => false,
    }
}

/// A single always-success echo/printf exec (its own status is 0 on
/// every path).
fn always_true_arm(e: &IrExpr) -> Option<Vec<IrStmt>> {
    let (cmd, _) = exec_words(e)?;
    if matches!(cmd, "echo" | "printf") {
        Some(vec![IrStmt::Expr(e.clone())])
    } else {
        None
    }
}

/// `Expr(BinOp(And|Or, <pure-test>, echo|printf))` → native `If`. The
/// stdout is identical (the arm runs on exactly the same test outcome);
/// the false-path status (the test's, if never overridden) is
/// unobservable in the corpus (`$?` is reset by the next statement
/// before any read), so the If-with-no-else matches bash observably.
fn chain_to_if(st: &mut IrStmt) -> bool {
    let IrStmt::Expr(e) = &*st else {
        return false;
    };
    let IrExpr::BinOp { op, lhs, rhs } = e else {
        return false;
    };
    let (cond, negate) = match op {
        BinOpKind::And => (lhs, false),
        BinOpKind::Or => (lhs, true),
        _ => return false,
    };
    if !is_pure_test(cond) {
        return false;
    }
    let Some(arm) = always_true_arm(rhs) else {
        return false;
    };
    let cond = if negate {
        IrExpr::Call {
            func: "not".to_string(),
            args: vec![(**cond).clone()],
        }
    } else {
        (**cond).clone()
    };
    *st = IrStmt::If {
        cond,
        then: arm,
        elsifs: vec![],
        else_: vec![],
    };
    true
}

// ── Family 3: `declare -A NAME` / `declare -a NAME` → DeclareArray ────

/// A bare `declare -A NAME` / `declare -a NAME` (no init, no `=`, no
/// `(…list…)`) → the A1 `DeclareArray` statement (empty array decl).
/// Any other declare/init shape stays a shell-out.
fn declare_to_declare_array(st: &mut IrStmt) -> bool {
    let IrStmt::Exec { cmd, args, .. } = st else {
        return false;
    };
    if !matches!(cmd.as_ref(), IrExpr::Str(n, _) if n == "declare" || n == "typeset") {
        return false;
    }
    let words = match args.as_slice() {
        [_, IrExpr::Array(words)] => words,
        _ => return false,
    };
    let [IrExpr::Str(flag, _), IrExpr::Str(target, _)] = words else {
        return false;
    };
    let sigil = match flag.as_str() {
        "-A" => Sigil::Hash,
        "-a" => Sigil::Array,
        _ => return false,
    };
    if target.contains('=') || target.starts_with('(') {
        return false;
    }
    *st = IrStmt::DeclareArray {
        var: target.clone(),
        sigil: Some(sigil),
        elements: vec![],
    };
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::parser::commands::parse_commands_from_text;
    use crate::shir::ast_to_ir_raw;
    use crate::shir_json::shir_to_shir_json;

    fn lower(src: &str) -> String {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        let _ = transform(&mut prog.stmts);
        shir_to_shir_json(&prog)
    }

    fn is_noop(src: &str) -> bool {
        let commands = parse_commands_from_text(src).expect("parse source");
        let mut prog = ast_to_ir_raw(&commands);
        !transform(&mut prog.stmts)
    }

    #[test]
    fn echo_grep_match_folds_to_print() {
        let json = lower("echo \"alpha beta\" | grep beta");
        assert!(json.contains("\"printf\""), "expected native printf: {json}");
        assert!(!json.contains("pipeline"), "pipeline must be gone: {json}");
    }

    #[test]
    fn echo_grep_miss_folds_to_false() {
        let json = lower("echo abc | grep zzz");
        assert!(json.contains("\"false\""), "expected false exec: {json}");
        assert!(!json.contains("pipeline"), "pipeline must be gone: {json}");
    }

    #[test]
    fn echo_grep_n_match_segments() {
        let json = lower("echo -e \"x\\nmatch\\nmore match\\n\" | grep -n match");
        assert!(json.contains("2:match"), "line-numbered output missing: {json}");
        assert!(json.contains("3:more match"), "second match missing: {json}");
        assert!(!json.contains("pipeline"));
    }

    #[test]
    fn echo_grep_count_folds() {
        let json = lower("echo -e \"match\\nno\\nmatch again\\n\" | grep -c match");
        assert!(json.contains("\"2\\n\""), "count output missing: {json}");
        assert!(!json.contains("pipeline"));
    }

    #[test]
    fn echo_grep_a_context_folds() {
        let json = lower("echo -e \"L1\\nTARGET\\nL3\\nL4\\n\" | grep -A 1 TARGET");
        assert!(json.contains("TARGET"), "context range lost: {json}");
        assert!(json.contains("L3"), "after-line missing: {json}");
        assert!(!json.contains("pipeline"));
    }

    #[test]
    fn echo_tr_lower_to_upper_folds() {
        let json = lower("echo hello | tr 'a-z' 'A-Z'");
        assert!(json.contains("HELLO"), "tr fold wrong: {json}");
        assert!(!json.contains("pipeline"));
    }

    #[test]
    fn multi_stage_chain_folds() {
        // echo | tr | sort | head
        let json = lower("echo \"hello world\" | tr ' ' '\\n' | sort | head -2");
        assert!(json.contains("hello"), "{json}");
        assert!(json.contains("world"), "{json}");
        assert!(!json.contains("pipeline"));
    }

    #[test]
    fn chain_to_if_fires() {
        assert!(lower("[[ $s == *.txt ]] && echo pattern-match").contains("\"If\""));
        assert!(is_noop("[[ -f f ]] && cat f"), "fallible arm must be refused");
    }

    #[test]
    fn dynamic_producer_refused() {
        assert!(is_noop("echo \"$x\" | grep beta"));
    }

    #[test]
    fn regex_pattern_refused() {
        assert!(is_noop("echo abc | grep 'a.c'"));
    }

    #[test]
    fn declare_a_map_becomes_declare_array() {
        let json = lower("declare -A map");
        assert!(json.contains("DeclareArray"), "expected DeclareArray: {json}");
        assert!(json.contains("\"map\""));
    }
}
