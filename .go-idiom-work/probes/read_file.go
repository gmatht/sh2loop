// read_file: os.ReadFile(path) — the whole-file read. The frontend
// lowers `b, _ := os.ReadFile(path)` to the cmdsub b = $(cat path)
// (t34's capture node; cat is an Emulable sync builtin; the []byte
// result is a string in the A1's strings-are-bytes model). Hermetic:
// the probe reads /dev/null — deterministic empty content, no files,
// no state. The if-init form (`if b, err := os.ReadFile(p); err ==
// nil {`) stays REFUSED: its cond is a read-status test, and the A1
// If cond is a `test` call, not a command status.
b, _ := os.ReadFile("/dev/null")
fmt.Println(len(b))
