// minimal flat config for the TRANSPILED/generated JS (the sh2 runtime
// surface: process, the sh2 object, async top-level) — the lint checks
// syntax/shape, not style nits.
export default [
  { files: ["**/*.mjs", "**/*.js"], languageOptions: { ecmaVersion: 2022, sourceType: "module", globals: { process: "readonly", console: "readonly", sh2: "readonly" } } },
];
