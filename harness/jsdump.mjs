#!/usr/bin/env node
// jsdump.mjs — pretty-print the ESTree JSON for a file (compact JS-ish).
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = '/home/llm/sh2loop';
const debashc = `${root}/sh2perl/target/debug/debashc`;
const file = process.argv[2];
let json;
try {
  json = JSON.parse(execFileSync(debashc, ['file', '--estree', file], { cwd: `${root}/sh2perl`, stdio: ['ignore', 'pipe', 'ignore'] }).toString());
} catch (e) {
  console.error(String(e));
  process.exit(1);
}

function pp(n, ind = '') {
  if (n == null) return String(n);
  if (typeof n === 'string') return JSON.stringify(n);
  if (typeof n === 'number') return String(n);
  if (Array.isArray(n)) return '[' + n.map(x => pp(x)).join(', ') + ']';
  const t = n.type;
  switch (t) {
    case 'Literal': return JSON.stringify(n.value ?? n.raw);
    case 'Identifier': return n.name;
    case 'MemberExpression': return pp(n.object) + (n.computed ? '[' + pp(n.property) + ']' : '.' + pp(n.property));
    case 'CallExpression': return pp(n.callee) + '(' + (n.arguments || []).map(x => pp(x)).join(', ') + ')';
    case 'ArrowFunctionExpression': return '(' + (n.params || []).map(pp).join(',') + ' => ' + pp(n.body) + ')';
    case 'BlockStatement': return '{\n' + ind + '  ' + (n.body || []).map(x => pp(x, ind + '  ')).join(';\n' + ind + '  ') + '\n' + ind + '}';
    case 'ExpressionStatement': return pp(n.expression);
    case 'SequenceExpression': return '(' + (n.expressions || []).map(pp).join(', ') + ')';
    case 'BinaryExpression': return '(' + pp(n.left) + ' ' + n.operator + ' ' + pp(n.right) + ')';
    case 'LogicalExpression': return '(' + pp(n.left) + ' ' + n.operator + ' ' + pp(n.right) + ')';
    case 'AssignmentExpression': return '(' + pp(n.left) + ' ' + n.operator + ' ' + pp(n.right) + ')';
    case 'VariableDeclaration': return (n.kind || 'let') + ' ' + (n.declarations || []).map(d => pp(d.id) + (d.init ? ' = ' + pp(d.init) : '')).join(', ');
    case 'TemplateLiteral': return '`' + (n.quasis || []).map((q, i) => (q.value?.raw ?? '') + (n.expressions?.[i] ? '${' + pp(n.expressions[i]) + '}' : '')).join('') + '`';
    case 'TryStatement': return 'try ' + pp(n.block) + ' catch(' + pp(n.param) + ') ' + pp(n.handler.body);
    case 'IfStatement': return 'if(' + pp(n.test) + ') ' + pp(n.consequent) + (n.alternate ? ' else ' + pp(n.alternate) : '');
    case 'ReturnStatement': return 'return ' + pp(n.argument);
    case 'ForStatement': return 'for(' + pp(n.init) + ';' + pp(n.test) + ';' + pp(n.update) + ') ' + pp(n.body);
    case 'WhileStatement': return 'while(' + pp(n.test) + ') ' + pp(n.body);
    case 'ThrowStatement': return 'throw ' + pp(n.argument);
    case 'NewExpression': return 'new ' + pp(n.callee) + '(' + (n.arguments || []).map(pp).join(', ') + ')';
    case 'UnaryExpression': return n.operator + pp(n.argument);
    case 'UpdateExpression': return n.prefix ? n.operator + pp(n.argument) : pp(n.argument) + n.operator;
    case 'ConditionalExpression': return '(' + pp(n.test) + ' ? ' + pp(n.consequent) + ' : ' + pp(n.alternate) + ')';
    case 'AwaitExpression': return 'await ' + pp(n.argument);
    case 'Program': return (n.body || []).map(x => pp(x)).join(';\n');
    case 'VariableDeclarator': return pp(n.id) + (n.init ? ' = ' + pp(n.init) : '');
    default: return '<' + t + '>';
  }
}
console.log(pp(json));
