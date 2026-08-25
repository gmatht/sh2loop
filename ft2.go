package main

import "fmt"

func apply(fn func(int) int, x int) int {
	return fn(x)
}

func main() {
	fmt.Println("hi")
}
