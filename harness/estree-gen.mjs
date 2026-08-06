// estree-gen.mjs — deterministic ESTree JSON → JS text printer.
//
// The sh2perl emitter produces a FIXED vocabulary of standard ESTree nodes
// (src/estree.rs). @babel/generator rejects plain JSON objects in 7.x/8.x
// (it requires @babel/types node instances), so this printer renders the
// same vocabulary directly. It is intentionally strict: any node type it
// does not know throws, so the harness fails loudly if the emitter grows a
// construct the runner cannot print.
//
// Output is used only as an intermediate: the reference executor runs it
// under node with the `sh2` namespace global (see estree-runner.mjs).

// Operator precedence (higher binds tighter). Used to decide parens.
const PREC = {
  Literal: 20, Identifier: 20, ArrayExpression: 20, ObjectExpression: 20,
  TemplateLiteral: 20, MemberExpression: 18, CallExpression: 18,
  AwaitExpression: 16, UnaryExpression: 15,
  LogicalExpression: 10, // && / || (9-10); treat uniformly, parenthesize nesting
  SequenceExpression: 1,
};

// A SequenceExpression inside a comma-separated position (call arguments,
// array elements, ternary branches) must be parenthesized or the commas
// would split it into separate arguments/elements.
function parenSeq(n, inner) {
  return n.type === 'SequenceExpression' ? `(${inner})` : inner;
}

function expr(node, parentPrec = 0) {
  const s = exprUnwrapped(node);
  const p = PREC[node.type] ?? 0;
  return p < parentPrec ? `(${s})` : s;
}

function exprUnwrapped(node) {
  switch (node.type) {
    case 'Identifier':
      return node.name;
    case 'Literal': {
      // regex literal (`/\s+/`): ESTree Literal-with-regex, emitted by
      // the native wc -w word-count lowering and the native case-glob
      // lowering. A literal regex cannot contain raw line terminators
      // (newline/CR/U+2028/U+2029) — glob patterns may embed real
      // newlines (`case $x in *'\n'*`), so escape them.
      if (node.regex) {
        const pat = node.regex.pattern
          .replace(/\r/g, '\\r')
          .replace(/\n/g, '\\n')
          .replace(/\u2028/g, '\\u2028')
          .replace(/\u2029/g, '\\u2029');
        return `/${pat}/${node.regex.flags}`;
      }
      const v = node.value;
      if (typeof v === 'string') return JSON.stringify(v);
      if (v === null) return 'null';
      if (typeof v === 'number') return String(v);
      if (typeof v === 'boolean') return String(v);
      if (Array.isArray(v) || typeof v === 'object') return JSON.stringify(v);
      throw new Error(`Literal with unprintable value: ${JSON.stringify(v)}`);
    }
    case 'TemplateLiteral': {
      let out = '`';
      for (let i = 0; i < node.quasis.length; i++) {
        const raw = node.quasis[i].value.raw ?? '';
        // Escape backticks and ${ sequences inside the raw text.
        out += raw.replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$\{/g, '\\${');
        if (i < node.expressions.length) out += '${' + parenSeq(node.expressions[i], expr(node.expressions[i])) + '}';
      }
      return out + '`';
    }
    case 'CallExpression': {
      // The A1 `split` marker (unquoted expansions — exec args, for-iters)
      // is emitted by the core as a NATIVE inline `String(x).split(/\s+/)
      // .filter(w => w.length > 0)`. Dispatch it through `sh2.split`
      // instead: identical for bash semantics (sh2.split implements the
      // same split), but lets the runtime resolve SOURCE-LANGUAGE
      // differences at the execution boundary — zsh never field-splits
      // unquoted expansions (SH_WORD_SPLIT off by default), so in zsh
      // mode sh2.split returns the whole value as a single field (the
      // _setLang mechanism, same as 1-based arrays).
      const inner = splitInlineArg(node);
      if (inner !== null) {
        return `sh2.split(${parenSeq(inner, expr(inner))})`;
      }
      return `${expr(node.callee, PREC.CallExpression)}(${node.arguments.map(a => parenSeq(a, expr(a))).join(', ')})`;
    }
    case 'MemberExpression': {
      const obj = expr(node.object, PREC.MemberExpression);
      if (node.computed) return `${obj}[${parenSeq(node.property, expr(node.property))}]`;
      return `${obj}.${expr(node.property, PREC.MemberExpression)}`;
    }
    case 'AwaitExpression':
      return `await ${parenSeq(node.argument, expr(node.argument, PREC.AwaitExpression))}`;
    case 'UnaryExpression':
      // prefix: ++x / --x / !x / -x …; postfix: x++ / x-- (arith IncDec)
      // `typeof` needs a space after the keyword (a bare `typeofx` would
      // parse as one identifier) — the only word-operator in the surface.
      return node.prefix
        ? `${node.operator}${node.operator === 'typeof' ? ' ' : ''}${parenIfCompound(node.argument)}`
        : `${parenIfCompound(node.argument)}${node.operator}`;
    case 'ArrowFunctionExpression': {
      const params = `(${node.params.map(p => expr(p)).join(', ')})`;
      const body = node.expression
        ? parenSeq(node.body, expr(node.body))   // `() => (a, b)` — a bare sequence body would bind wrong
        : printStatement(node.body);
      return `${node.async ? 'async ' : ''}${params} => ${body}`;
    }
    case 'ArrayExpression':
      // SpreadElement elements print as `...x` (never parenSeq-wrapped:
      // `(...x)` inside an array literal is a SyntaxError)
      return `[${node.elements.map(e => e === null || e === undefined ? '' : e.type === 'SpreadElement' ? expr(e) : parenSeq(e, expr(e))).join(', ')}]`;
    case 'SpreadElement':
      return `...${parenSeq(node.argument, expr(node.argument))}`;
    case 'RestElement':
      return `...${expr(node.argument)}`;
    case 'ObjectExpression':
      return `{${node.properties.map(prop).join(', ')}}`;    case 'LogicalExpression':
      // Parenthesize compound operands: `??` must never mix bare with
      // `&&`/`||` (SyntaxError), and nested same-op pairs are always safe
      // with parens.
      return `${parenIfCompound(node.left)} ${node.operator} ${parenIfCompound(node.right)}`;
    case 'BinaryExpression': {
      // Parenthesize nested binary/logical/conditional operands so the
      // printer never changes operator precedence (the AST tree already
      // encodes it).
      const l = parenIfCompound(node.left);
      const r = parenIfCompound(node.right);
      return `${l} ${node.operator} ${r}`;
    }
    case 'AssignmentExpression':
      return `${expr(node.left)} ${node.operator} ${parenSeq(node.right, expr(node.right))}`;
    case 'ConditionalExpression': {
      const t = parenIfCompound(node.test);
      const c = parenIfCompound(node.consequent);
      const a = parenIfCompound(node.alternate);
      return `${t} ? ${c} : ${a}`;
    }
    case 'SequenceExpression':
      return node.expressions.map(e => expr(e, PREC.SequenceExpression)).join(', ');
    default:
      throw new Error(`estree-gen: unknown expression node type ${node.type}`);
  }
}

function parenIfCompound(n) {
  return ['BinaryExpression', 'LogicalExpression', 'ConditionalExpression', 'ArrowFunctionExpression', 'SequenceExpression'].includes(n.type)
    ? `(${expr(n)})`
    : expr(n);
}

// splitInlineArg — recognize the emitter's native inline field-split shape
// `String(x).split(/\s+/).filter((w) => w.length > 0)` (the A1 `split`
// marker lowered to ESTree by src/shir.rs) and return the inner `x`
// expression; null for anything else (the printer stays strict).
function splitInlineArg(n) {
  if (n.type !== 'CallExpression') return null;
  const callee = n.callee;
  if (
    callee?.type !== 'MemberExpression' || callee.computed ||
    callee.property?.type !== 'Identifier' || callee.property.name !== 'filter' ||
    n.arguments.length !== 1 || n.arguments[0].type !== 'ArrowFunctionExpression'
  ) return null;
  const arrow = n.arguments[0];
  if (
    arrow.params.length !== 1 || arrow.params[0].type !== 'Identifier' ||
    arrow.body?.type !== 'BinaryExpression' || arrow.body.operator !== '>' ||
    arrow.body.right?.type !== 'Literal' || arrow.body.right.value !== 0 ||
    arrow.body.left?.type !== 'MemberExpression' ||
    arrow.body.left.object?.type !== 'Identifier' ||
    arrow.body.left.object.name !== arrow.params[0].name ||
    arrow.body.left.property?.type !== 'Identifier' ||
    arrow.body.left.property.name !== 'length'
  ) return null;
  const splitCall = callee.object;
  if (
    splitCall?.type !== 'CallExpression' || splitCall.arguments.length !== 1 ||
    splitCall.arguments[0]?.type !== 'Literal' ||
    splitCall.arguments[0].regex?.pattern !== '\\s+' ||
    splitCall.callee?.type !== 'MemberExpression' || splitCall.callee.computed ||
    splitCall.callee.property?.type !== 'Identifier' || splitCall.callee.property.name !== 'split'
  ) return null;
  const strCall = splitCall.callee.object;
  if (
    strCall?.type !== 'CallExpression' || strCall.arguments.length !== 1 ||
    strCall.callee?.type !== 'Identifier' || strCall.callee.name !== 'String'
  ) return null;
  return strCall.arguments[0];
}

function prop(p) {
  const key = p.computed ? `[${expr(p.key)}]` : expr(p.key);
  return `${key}: ${parenSeq(p.value, expr(p.value))}`;
}

export function printStatement(node) {
  switch (node.type) {
    case 'ExpressionStatement':
      return `${expr(node.expression)};`;
    case 'BlockStatement':
      return `{ ${node.body.map(printStatement).join(' ')} }`;
    case 'IfStatement': {
      let out = `if (${expr(node.test)}) ${printStatement(node.consequent)}`;
      if (node.alternate) out += ` else ${printStatement(node.alternate)}`;
      return out;
    }
    case 'SwitchStatement':
      return `switch (${expr(node.discriminant)}) { ${node.cases.map(switchCase).join(' ')} }`;
    case 'WhileStatement':
      return `while (${expr(node.test)}) ${printStatement(node.body)}`;
    case 'ForStatement':
      // init is a VariableDeclaration (`let i = lo`); test `i <= hi`;
      // update `i++` — the native numeric-range loop (seq_range_for).
      return `for (${printStatement(node.init).replace(/;$/, '')}; ${expr(node.test)}; ${expr(node.update)}) ${printStatement(node.body)}`;
    case 'ForOfStatement':
      return `for (${printStatement(node.left).replace(/;$/, '')} of ${expr(node.right)}) ${printStatement(node.body)}`;
    case 'VariableDeclaration': {
      const decls = node.declarations
        .map(d => `${expr(d.id)}${d.init ? ' = ' + parenSeq(d.init, expr(d.init)) : ''}`)
        .join(', ');
      return `${node.kind} ${decls};`;
    }
    case 'BreakStatement':
      return `break${node.label ? ' ' + node.label : ''};`;
    case 'ContinueStatement':
      return `continue${node.label ? ' ' + node.label : ''};`;
    case 'ReturnStatement':
      return `return${node.argument ? ' ' + expr(node.argument) : ''};`;
    default:
      throw new Error(`estree-gen: unknown statement node type ${node.type}`);
  }
}

function switchCase(c) {
  const head = c.test ? `case ${expr(c.test)}:` : 'default:';
  return `${head} ${c.consequent.map(printStatement).join(' ')}`;
}

/** Render a full Program to JS module text. */
export function generate(program) {
  if (program.type !== 'Program') throw new Error(`estree-gen: expected Program, got ${program.type}`);
  const body = program.body.map(printStatement).join('\n');
  return body + (body ? '\n' : '');
}
