find / -type f -exec file {} + | grep -i "shell script" | cut -d: -f1 | tee allshell.txt
