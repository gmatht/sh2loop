// fix_builtin_fallback.go — idempotent patcher: make the backends render
// the A1 `builtin` op like `exec` (the self-fallback arm the marketplace
// acceptance rule requires). Idempotent: a line already carrying the
// builtin fallback is left alone; broken double-patches are repaired.
//
// Replaces:
//   "exec" =>                          →  "exec" | "builtin" =>
//   func == "exec"                     →  func == "exec" || func == "builtin"
//   func == "exec" || func == "builtin" | "builtin"   (broken) → clean
//
// Usage: go run fix_builtin_fallback.go <file>...
package main

import (
	"fmt"
	"os"
	"strings"
)

func patch(path string) int {
	b, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", path, err)
		return 0
	}
	s := string(b)
	orig := s
	n := 0

	// repair broken double-patches first (collapse repeats idempotently)
	for strings.Contains(s, `|| func == "builtin" || func == "builtin"`) {
		s = strings.ReplaceAll(s, `|| func == "builtin" || func == "builtin"`, `|| func == "builtin"`)
	}
	for strings.Contains(s, `"exec" | "builtin" | "builtin" =>`) {
		s = strings.ReplaceAll(s, `"exec" | "builtin" | "builtin" =>`, `"exec" | "builtin" =>`)
	}

	// idempotent match arms: "exec" =>  →  "exec" | "builtin" =>
	for {
		i := strings.Index(s, `"exec" =>`)
		if i < 0 {
			break
		}
		// already patched? ("exec" | "builtin" => is fine)
		if i >= 5 && s[i-5:i] == `" | "` {
			break // previous occurrence chain already has builtin
		}
		s = s[:i] + `"exec" | "builtin" =>` + s[i+len(`"exec" =>`):]
		n++
	}

	// idempotent guards: func == "exec" → func == "exec" || func == "builtin"
	for {
		i := strings.Index(s, `func == "exec"`)
		if i < 0 {
			break
		}
		rest := s[i+len(`func == "exec"`):]
		if strings.HasPrefix(rest, ` || func == "builtin"`) {
			break // already patched
		}
		s = s[:i] + `func == "exec" || func == "builtin"` + rest
		n++
	}

	if s != orig {
		if err := os.WriteFile(path, []byte(s), 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", path, err)
			return 0
		}
	}
	fmt.Printf("%s: %d patch(es)\n", path, n)
	return n
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: go run fix_builtin_fallback.go <file>...")
		os.Exit(2)
	}
	total := 0
	for _, f := range os.Args[1:] {
		total += patch(f)
	}
	fmt.Printf("total: %d patches\n", total)
}
