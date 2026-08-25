apply := func(fn func(int) int, x int) int {
    return fn(x)
}
fmt.Println(apply(func(v int) int { return v + 1 }, 41))
