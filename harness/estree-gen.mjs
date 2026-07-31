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
};

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
      const v = node.value;
      if (typeof v === 'string') return JSON.stringify(v);
      if (v === null) return 'null';
      if (typeof v === 'number') return String(v);
      if (typeof v === 'boolean') return String(v);
      throw new Error(`Literal with unprintable value: ${JSON.stringify(v)}`);
    }
    case 'TemplateLiteral': {
      let out = '`';
      for (let i = 0; i < node.quasis.length; i++) {
        const raw = node.quasis[i].value.raw ?? '';
        // Escape backticks and ${ sequences inside the raw text.
        out += raw.replace(/\\/g, '\\\\').replace(/`/g, '\\`').replace(/\$\{/g, '\\${');
        if (i < node.expressions.length) out += '${' + expr(node.expressions[i]) + '}';
      }
      return out + '`';
    }
    case 'CallExpression':
      return `${expr(node.callee, PREC.CallExpression)}(${node.arguments.map(a => expr(a)).join(', ')})`;
    case 'MemberExpression': {
      const obj = expr(node.object, PREC.MemberExpression);
      if (node.computed) return `${obj}[${expr(node.property)}]`;
      return `${obj}.${expr(node.property, PREC.MemberExpression)}`;
    }
    case 'AwaitExpression':
      return `await ${expr(node.argument, PREC.AwaitExpression)}`;
    case 'UnaryExpression':
      return `${node.operator}${expr(node.argument, PREC.UnaryExpression)}`;
    case 'ArrowFunctionExpression': {
      const params = `(${node.params.map(p => expr(p)).join(', ')})`;
      const body = node.expression
        ? expr(node.body)
        : printStatement(node.body);
      return `${node.async ? 'async ' : ''}${params} => ${body}`;
    }
    case 'ArrayExpression':
      return `[${node.elements.map(e => e === null || e === undefined ? '' : expr(e)).join(', ')}]`;
    case 'ObjectExpression':
      return `{${node.properties.map(prop).join(', ')}}`;
    case 'LogicalExpression':
      return `${expr(node.left, PREC.LogicalExpression)} ${node.operator} ${expr(node.right, PREC.LogicalExpression)}`;
    default:
      throw new Error(`estree-gen: unknown expression node type ${node.type}`);
  }
}

function prop(p) {
  const key = p.computed ? `[${expr(p.key)}]` : expr(p.key);
  return `${key}: ${expr(p.value)}`;
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
        .map(d => `${expr(d.id)}${d.init ? ' = ' + expr(d.init) : ''}`)
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
