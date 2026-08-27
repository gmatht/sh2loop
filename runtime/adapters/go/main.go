// adapters/go/main.go — the Go backend's thin adapter for the C
// polyfills. Links libsh2poly.a via cgo and maps the sh2.* call-site
// convention to sh2poly_dispatch.
//
// Build: go build -o sh2poly-adapter .
// Run:   ./sh2poly-adapter   (reads adapters/battery.txt)
//
// The battery runner: reads battery.txt (TAB-separated fields, `\\` →
// backslash, `\n` → newline), sets up the deterministic stdin,
// dispatches every call, prints `== name` / `status=N`.
package main

/*
#cgo LDFLAGS: -L../.. -l:libsh2poly.a
#include <stdlib.h>
#include <unistd.h>
void sh2poly_init();
int sh2poly_dispatch(int argc, char **argv);
*/
import "C"

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"unsafe"
)

func unescape(field string) string {
	var b strings.Builder
	for i := 0; i < len(field); i++ {
		if field[i] == '\\' && i+1 < len(field) {
			switch field[i+1] {
			case '\\':
				b.WriteByte('\\')
				i++
			case 'n':
				b.WriteByte('\n')
				i++
			case 't':
				b.WriteByte('\t')
				i++
			default:
				b.WriteByte('\\')
			}
		} else {
			b.WriteByte(field[i])
		}
	}
	return b.String()
}

func dispatch(name string, args []string) int {
	argv := make([]*C.char, 0, len(args)+2)
	argv = append(argv, C.CString(name))
	for _, a := range args {
		argv = append(argv, C.CString(a))
	}
	argv = append(argv, nil)
	defer func() {
		for _, p := range argv {
			if p != nil {
				C.free(unsafe.Pointer(p))
			}
		}
	}()
	st := C.sh2poly_dispatch(C.int(len(argv)-1), &argv[0])
	return int(st)
}

func main() {
	C.sh2poly_init()

	// deterministic stdin for the read/readarray calls
	os.WriteFile("/tmp/sh2poly_selftest_in.txt", []byte("alpha beta gamma\none\ntwo\nthree\n"), 0644)
	in, err := os.Open("/tmp/sh2poly_selftest_in.txt")
	if err != nil {
		panic(err)
	}
	defer in.Close()
	C.dup2(C.int(in.Fd()), 0)

	bat, err := os.Open("adapters/battery.txt")
	if err != nil {
		bat, err = os.Open("battery.txt")
		if err != nil {
			panic(err)
		}
	}
	defer bat.Close()

	sc := bufio.NewScanner(bat)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		fields := strings.Split(line, "\t")
		name := fields[0]
		args := make([]string, 0, len(fields)-1)
		for _, f := range fields[1:] {
			args = append(args, unescape(f))
		}
		fmt.Printf("== %s\n", name)
		st := dispatch(name, args)
		fmt.Printf("status=%d\n", st)
	}
}
