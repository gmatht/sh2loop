// write_file: os.WriteFile(path, []byte(content), perm) — the whole-file
// write. The frontend lowers the literal form to the A1 Redirect shape
// `echo content > path` (t32's redirect). Hermetic: the probe writes to
// /dev/stdout — deterministic bytes, no files, no state.
os.WriteFile("/dev/stdout", []byte("hi\n"), 0o644)
