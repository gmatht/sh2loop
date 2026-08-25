var x any = "hi"
switch v := x.(type) {
case string:
    fmt.Println("string", v)
default:
    fmt.Println("other")
}
