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
      // the native wc -w word-count lowering
      if (node.regex) return `/${node.regex.pattern}/${node.regex.flags}`;
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
    case 'CallExpression':
      return `${expr(node.callee, PREC.CallExpression)}(${node.arguments.map(a => parenSeq(a, expr(a))).join(', ')})`;
    case 'MemberExpression': {
      const obj = expr(node.object, PREC.MemberExpression);
      if (node.computed) return `${obj}[${parenSeq(node.property, expr(node.property))}]`;
      return `${obj}.${expr(node.property, PREC.MemberExpression)}`;
    }
    case 'AwaitExpression':
      return `await ${parenSeq(node.argument, expr(node.argument, PREC.AwaitExpression))}`;
    case 'UnaryExpression':
      // prefix: ++x / --x / !x / -x …; postfix: x++ / x-- (arith IncDec)
      return node.prefix
        ? `${node.operator}${parenIfCompound(node.argument)}`
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
