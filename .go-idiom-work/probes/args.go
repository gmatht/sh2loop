// args: os.Args[1:] — the program's argv with argv0 stripped (the
// shell's `"$@"`). BOUNDARY: the A1/runtime resolve positional state
// as SCALARS only (getVar("@") → the space-joined string, getVar("#")
// → the count, $1..$9 → one element); there is NO array-valued
// materialization of the positional list in the JS runtime (the shir
// side's listVar has no runtime counterpart), so `args` cannot be
// stored as an array value — len/args[i]/range all read the array
// store. The probe stays red, documented (core-requests/
// go-sh-dogfood-20260815-contract-boundaries.md §11). fail-go runs
// the oracle with no args, so len(os.Args[1:]) is deterministically 0.
args := os.Args[1:]
fmt.Println(len(args))
