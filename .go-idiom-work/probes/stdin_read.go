r := bufio.NewReader(os.Stdin)
line, _ := r.ReadString("\n"[0])
fmt.Println("got", line)
