package main

// otranspiler — the unified user-facing interface: one command over the
// frontend + backend fleet. Extension-driven source/target dispatch,
// shell as the default language, '-' for stdout, and the neutral A1
// (.shir) as a first-class format in both directions.
//
//   otranspiler <input> [<output>] [flags]
//     input  file.{py,c,pl,sh,zsh,fish,go,shir}   (no ext = sh)
//     output {-,file}.{c,js,pl,sh,go,rs,zig,java,py,shir}  (no ext = sh, - = stdout)
//   flags:
//     --source-lang L   force the source language (a .sh could be zsh)
//     --target L        force the target language
//     --run             JS target: execute via the estree runner, not just emit
//     --shir            output the raw A1 contract (alias for .shir)
//     -h|--help         usage
//
// The A1 shIR JSON is backend-neutral: one contract, every backend.

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// ── the dispatch tables (the single source of truth) ─────────────────
// source extension → frontend command (the A1 emitters)
var sources = map[string]string{
	".py":   "frontends/py-sh-go/py-sh-go",
	".c":    "frontends/c-sh-go/c-sh-go",
	".pl":   "frontends/perl-sh-go/perl-sh-go",
	".zsh":  "frontends/zsh-sh-go/zsh-sh-go",
	".fish": "frontends/fish-sh-go/fish-sh-go",
	".go":   "frontends/go-sh/go-sh",
	// .sh and no-ext: the core itself (debashc --shir)
}
// target extension → the backend invocation: "flag:<lang>" = the main
// debashc's --shir-in-<lang>; "bin:<path>" = a worktree bin taking the A1
// on stdin; "" = the neutral A1 contract itself (no backend)
var targets = map[string]string{
	".js":   "flag:estree",
	".pl":   "flag:perl",
	".c":    "bin:sh2perl/backends/c/target/debug/shir_to_c",
	".shir": "",
	// .sh/.go/.rs/.zig/.java/.py — the worktree renderers exist but the
	// --shir-in-<lang> ingress flags are not wired yet: emit a clear error.
}

func workspaceRoot() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	// <ws>/otranspiler/otranspiler → <ws>
	return filepath.Dir(filepath.Dir(exe))
}

func run(cmd *exec.Cmd) ([]byte, error) {
	var out, errb bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &errb
	err := cmd.Run()
	if err != nil && errb.Len() > 0 {
		return out.Bytes(), fmt.Errorf("%v: %s", err, strings.TrimSpace(errb.String()))
	}
	return out.Bytes(), err
}

func usage() {
	fmt.Fprintln(os.Stderr, `otranspiler <input> [<output>] [flags]
  input  file.{py,c,pl,sh,zsh,fish,go,shir}   (no ext = sh; - = A1 from stdin)
  output {-,file}.{c,js,pl,sh,go,rs,zig,java,py,shir}  (no ext = sh; - = stdout)
  --source-lang L   force the source language
  --target L        force the target language
  --run             JS target: execute via the estree runner
  --shir            output the raw A1 contract (same as output ext .shir)`)
}

func main() {
	args := os.Args[1:]
	forceSrc, forceTgt, doRun := "", "", false
	var positional []string
	for _, a := range args {
		switch {
		case a == "-h" || a == "--help":
			usage()
			os.Exit(0)
		case a == "--run":
			doRun = true
		case a == "--shir":
			forceTgt = "shir"
		case a == "--source-lang":
			// --source-lang L (next arg consumed below)
		case strings.HasPrefix(a, "--source-lang="):
			forceSrc = strings.TrimPrefix(a, "--source-lang=")
		case strings.HasPrefix(a, "--target="):
			forceTgt = strings.TrimPrefix(a, "--target=")
		case a == "--source-lang" || a == "--target":
			// handled after the loop
		default:
			positional = append(positional, a)
		}
	}
	for i, a := range args {
		if (a == "--source-lang" || a == "--target") && i+1 < len(args) {
			if a == "--source-lang" {
				forceSrc = args[i+1]
			} else {
				forceTgt = args[i+1]
			}
		}
	}
	if len(positional) < 1 {
		usage()
		os.Exit(2)
	}
	input, output := positional[0], ""
	if len(positional) >= 2 {
		output = positional[1]
	}

	root := workspaceRoot()
	srcLang := forceSrc
	if srcLang == "" {
		srcLang = langOf(input)
	}
	tgtLang := forceTgt
	if tgtLang == "" && output != "" {
		tgtLang = langOf(output)
	}
	if tgtLang == "" {
		tgtLang = "js" // the default target (estree — the always-wired backend)
	}
	if tgtLang == "shir" {
		// emit the neutral A1: run the frontend (or pass .shir input through)
		var a1 []byte
		var err error
		if input == "-" || strings.HasSuffix(input, ".shir") {
			if input != "-" {
				a1, err = os.ReadFile(input)
			} else {
				a1, err = os.ReadFile("/dev/stdin")
			}
		} else {
			a1, err = emitA1(root, input, srcLang)
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, "otranspiler:", err)
			os.Exit(1)
		}
		writeOut(output, a1)
		return
	}

	// the pipeline: A1 -> the target backend -> output
	a1, err := emitA1(root, input, srcLang)
	if err != nil {
		fmt.Fprintln(os.Stderr, "otranspiler:", err)
		os.Exit(1)
	}
	out, err := render(root, tgtLang, a1)
	if err != nil {
		fmt.Fprintln(os.Stderr, "otranspiler:", err)
		os.Exit(1)
	}
	if tgtLang == "js" && doRun {
		runner := exec.Command("node", filepath.Join(root, "harness/estree-runner.mjs"), "/dev/stdin", "--source", input)
		runner.Stdin = bytes.NewReader(out)
		runner.Stdout = os.Stdout
		runner.Stderr = os.Stderr
		if err := runner.Run(); err != nil {
			fmt.Fprintln(os.Stderr, "otranspiler --run:", err)
			os.Exit(1)
		}
		return
	}
	writeOut(output, out)
}

// render — dispatch the A1 to the target backend.
func render(root, lang string, a1 []byte) ([]byte, error) {
	kind, ok := targets["."+lang]
	if !ok {
		return nil, fmt.Errorf("target %q not wired (the worktree renderer exists but the --shir-in-%s ingress flag is not connected)", lang, lang)
	}
	if kind == "" {
		return a1, nil // the neutral A1 contract itself
	}
	var cmd *exec.Cmd
	if strings.HasPrefix(kind, "flag:") {
		l := strings.TrimPrefix(kind, "flag:")
		cmd = exec.Command(filepath.Join(root, "sh2perl/target/debug/debashc"), "--shir-in-"+l, "-")
		cmd.Dir = filepath.Join(root, "sh2perl")
	} else if strings.HasPrefix(kind, "bin:") {
		cmd = exec.Command(filepath.Join(root, strings.TrimPrefix(kind, "bin:")), "-")
		cmd.Dir = root
	}
	cmd.Stdin = bytes.NewReader(a1)
	return run(cmd)
}

func langOf(path string) string {
	if path == "-" {
		return "shir" // stdin is treated as the A1 contract
	}
	switch filepath.Ext(path) {
	case ".py", ".c", ".pl", ".zsh", ".fish", ".go",
		".js", ".rs", ".zig", ".java": // source + target extensions
		return strings.TrimPrefix(filepath.Ext(path), ".")
	case ".shir":
		return "shir"
	default: // no extension or anything else → shell
		return "sh"
	}
}

func emitA1(root, input, srcLang string) ([]byte, error) {
	if input == "-" || srcLang == "shir" {
		if input != "-" {
			return os.ReadFile(input)
		}
		return os.ReadFile("/dev/stdin")
	}
	exe := filepath.Join(root, "sh2perl/target/debug/debashc")
	fe, ok := sources["."+srcLang]
	if !ok {
		fe = "" // shell (and the core's other flags): debashc --shir <file> --raw
	}
	cmd := exec.Command(exe, "--shir", input, "--raw")
	if fe != "" {
		cmd = exec.Command(filepath.Join(root, fe), "--shir", input, "--raw")
	}
	cmd.Dir = root
	if abs, err := filepath.Abs(input); err == nil {
		input = abs
	}
	out, err := run(cmd)
	if err != nil {
		return nil, fmt.Errorf("frontend %s: %w", srcLang, err)
	}
	return out, nil
}

func writeOut(output string, data []byte) {
	if output == "" || output == "-" {
		os.Stdout.Write(data)
		return
	}
	if err := os.WriteFile(output, data, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "otranspiler:", err)
		os.Exit(1)
	}
}
