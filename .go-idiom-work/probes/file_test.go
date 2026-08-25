// file_test: if _, err := os.Stat(path); err == nil { — the frontend
// lowers this init form to `if test -e path; then` (-e = exists, ANY
// type — Go's os.Stat succeeds for devices/dirs/symlinks, not just
// regular files). Hermetic: /dev/null always exists (a char device),
// /nonexistent-sh2probe never does — deterministic, no files, no state.
if _, err := os.Stat("/dev/null"); err == nil {
    fmt.Println("exists")
} else {
    fmt.Println("missing")
}
if _, err := os.Stat("/nonexistent-sh2probe"); err != nil {
    fmt.Println("no")
} else {
    fmt.Println("yes")
}
