out, _ := exec.Command("echo", "hi").Output()
fmt.Println(string(out))
