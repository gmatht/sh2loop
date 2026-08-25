// browser-shim.mjs — a BROWSER-EQUIVALENT runtime for compiled shIR
// programs: the same prog.mjs the Node estree-runner executes, imported
// against a SHIMMED `process` global. No `fs`, no real stdio — stdout
// writes land in a capture array, proving the emitted program's only
// Node surface is the injected `process` object (the sh2 namespace is
// bundled alongside it in a real browser deployment; see FRONTEND.md).
//
// Usage: node browser-shim.mjs <prog.mjs>
// Prints the captured program stdout to this process's stdout, so the
// Node runner's and this runner's outputs diff byte-for-byte.

const modPath = process.argv[2] ?? process.argv[1];
const realStdout = process.stdout.write.bind(process.stdout);
const captured = [];

globalThis.process = new Proxy(process, {
  get(target, key) {
    if (key === 'stdout') {
      return {
        write(s) {
          captured.push(String(s));
          return true;
        },
      };
    }
    if (key === 'exit') {
      return (code) => {
        throw { __shimExit: true, code };
      };
    }
    return Reflect.get(target, key);
  },
  // status/flag writes into the real process object are harmless;
  // swallow them so the shim stays hermetic
  set() {
    return true;
  },
});

try {
  await import(modPath);
} catch (e) {
  if (!(e && e.__shimExit)) {
    throw e;
  }
}
realStdout(captured.join(''));
