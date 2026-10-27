#!/usr/bin/env node
// test_printf_pieces.mjs — the printf format-piece cache must be
// output-identical to the per-call parse it replaced.
//
// formatOnce used to re-walk the format regex (and re-run unescapeFormat's
// nine replace chains) on EVERY pass. It is now parsed once per format and
// cached (printfPieces). This test keeps an independent copy of the OLD
// algorithm and asserts byte equality over a format battery, including the
// shapes that pin the cache's design:
//   - a literal run that itself starts with `%` (`"%z then %s"`)
//   - `%%` (a literal percent — NOT a conversion, must not consume an arg)
//   - formats with no conversion at all (the `ai` advance rule)
//   - more conversions than arguments, and more arguments than conversions
//   - repeated use of the same format (the cache hit path) with different
//     arguments
import { sh2 } from './sh2-namespace.mjs';

// ── the pre-change algorithm, verbatim ────────────────────────────────
function unescapeFormat(s) {
  return s
    .replace(/\\n/g, '\n')
    .replace(/\\t/g, '\t')
    .replace(/\\r/g, '\r')
    .replace(/\\a/g, '\x07')
    .replace(/\\b/g, '\b')
    .replace(/\\f/g, '\f')
    .replace(/\\v/g, '\v')
    .replace(/\\\\/g, '\\')
    .replace(/\\([0-7]{1,3})/g, (_, o) => String.fromCharCode(parseInt(o, 8)));
}
function oldFormatOnce(format, nextArg) {
  const specs = /%(?:[-+ 0#]*\d*(?:\.\d+)?[diouxXeEfgGcbsq%])/g;
  let out = '';
  let last = 0;
  let m;
  while ((m = specs.exec(format)) !== null) {
    out += unescapeFormat(format.slice(last, m.index));
    const spec = m[0];
    if (spec === '%%') { out += '%'; last = m.index + 2; continue; }
    out += oldPrintfOne(spec, nextArg());
    last = m.index + spec.length;
  }
  out += unescapeFormat(format.slice(last));
  return out;
}
function oldPrintfOne(spec, arg) {
  // the live printfOne, copied verbatim: the piece cache must not change
  // ANY conversion semantics, only the scheduling of the parse
  const a = arg === undefined ? '' : String(arg);
  const m = /^%([-+ 0#]*)(\d*)(?:\.(\d+))?([diouxXeEfgGcbsq%])$/.exec(spec) || [];
  const flags = m[1] ?? '';
  const width = m[2] ? Number(m[2]) : 0;
  const prec = m[3] ? Number(m[3]) : undefined;
  const conv = m[4] ?? spec.slice(-1);
  const pad = (s, left) => {
    if (width <= s.length) return s;
    const fill = flags.includes('0') && !flags.includes('-') && conv !== 's' ? '0' : ' ';
    const padN = width - s.length;
    return left ? s + fill.repeat(padN) : fill.repeat(padN) + s;
  };
  switch (conv) {
    case 's': return pad(a, flags.includes('-'));
    case 'q': return oldShellQuote(a);
    case 'd': case 'i': return pad(String(parseInt(a, 10) || 0), flags.includes('-'));
    case 'c': return pad(a[0] ?? '', flags.includes('-'));
    case 'b': return pad(a.replace(/\\n/g, '\n').replace(/\\t/g, '\t').replace(/\\0[0-7]{1,3}/g, m2 => String.fromCharCode(parseInt(m2.slice(1), 8))), flags.includes('-'));
    case 'x': return pad((parseInt(a, 10) || 0).toString(16), flags.includes('-'));
    case 'X': return pad((parseInt(a, 10) || 0).toString(16).toUpperCase(), flags.includes('-'));
    case 'o': return pad((parseInt(a, 10) || 0).toString(8), flags.includes('-'));
    case 'f': {
      let s = String(parseFloat(a) || 0);
      if (prec !== undefined) s = (parseFloat(a) || 0).toFixed(prec);
      return pad(s, flags.includes('-'));
    }
    default: return a;
  }
}
function oldShellQuote(s) {
  const safe = /^[A-Za-z0-9_.,:@%+=/-]*$/;
  if (safe.test(s)) return s;
  if (/[^\x20-\x7e]/.test(s)) {
    let out = "$'";
    for (const ch of s) {
      const c = ch.codePointAt(0);
      if (ch === '\\') out += '\\\\';
      else if (ch === "'") out += "\\'";
      else if (ch === '\n') out += '\\n';
      else if (ch === '\t') out += '\\t';
      else if (ch === '\r') out += '\\r';
      else if (c < 0x20 || c === 0x7f) out += '\\0' + c.toString(8).padStart(3, '0');
      else out += ch;
    }
    return out + "'";
  }
  return s.replace(/([^A-Za-z0-9_.,:@%+=/-])/g, '\\$1');
}
function oldPrintfFormat(format, args) {
  if (args.length === 0) return oldFormatOnce(format, () => '');
  let out = '';
  let ai = 0;
  while (ai < args.length) {
    let used = 0;
    out += oldFormatOnce(format, () => { used++; return args[ai + used - 1] ?? ''; });
    ai += Math.max(used, 1);
  }
  return out;
}

// ── capture the live builtin's output ─────────────────────────────────
let sink = '';
sh2._outSink = (fd, text) => { sink += text; };
function livePrintf(args) {
  sink = '';
  sh2.builtin('printf', args);
  return sink;
}

const cases = [
  [['plain text\\n']],
  [['%s=%s', 'a', 'b']],
  [['100%%\\n']],
  [['%%']],
  [['%z then %s', 'X']],
  [['%05d|%-5s|%5.2f', '42', 'ab', '3.14159']],
  [['no-conv', 'x']],
  [['%s ', 'a', 'b', 'c']],
  [['%d\\n', '7']],
  [['\\t%s\\n', 'q']],
  [['%o %x %X %c', '8', '255', '255', 'hello']],
  [['%e', '1234.5678']],
  [['%b', 'a\\tb']],
  [['%s\\n%s\\n', 'p']],
  [['%s-%s-%s\\n', '1']],
  [['1234', 'ignored']],
  [['']],
  [['', 'x']],
  [['\\101\\102\\103']],
  [['%s%s%s%s%s', 'a', 'b', 'c', 'd', 'e']],
  [['x%%y%%z %s', 'q']],
  [['%5s|%-5s|%+d|% d', 'a', 'b', '3', '4']],
  [['%s', '$&'], ['%s', '$1']],
];

let fail = 0;
for (const [args] of cases) {
  const want = oldPrintfFormat(args[0] ?? '', args.slice(1));
  const got = livePrintf(args);
  if (want !== got) { console.log(`MISMATCH ${JSON.stringify(args)}: want ${JSON.stringify(want)} got ${JSON.stringify(got)}`); fail++; }
}
// cache-hit path: same format, different arguments, repeated
for (let i = 0; i < 5; i++) {
  const args = ['%s=%d\\n', `k${i}`, String(i)];
  const want = oldPrintfFormat(args[0], args.slice(1));
  const got = livePrintf(args);
  if (want !== got) { console.log(`MISMATCH repeat ${JSON.stringify(args)}`); fail++; }
}
// the cache must not leak across formats with a common prefix
{
  const a = ['%sX', '1'], b = ['%z%sX', '2'];
  if (livePrintf(a) !== oldPrintfFormat(a[0], a.slice(1))) { console.log('MISMATCH prefix-a'); fail++; }
  if (livePrintf(b) !== oldPrintfFormat(b[0], b.slice(1))) { console.log('MISMATCH prefix-b'); fail++; }
  if (livePrintf(a) !== oldPrintfFormat(a[0], a.slice(1))) { console.log('MISMATCH prefix-a-again'); fail++; }
}
console.log(fail === 0 ? 'printf pieces: OK' : `printf pieces: ${fail} FAILURES`);
process.exit(fail === 0 ? 0 : 1);
