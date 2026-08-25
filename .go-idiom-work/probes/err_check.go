n, err := strconv.Atoi("42")
if err != nil {
    fmt.Println("bad")
} else {
    fmt.Println(n + 1)
}
