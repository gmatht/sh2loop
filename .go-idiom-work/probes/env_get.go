x := os.Getenv("X")
if x == "" {
    x = "def"
}
fmt.Println("a=" + x)
