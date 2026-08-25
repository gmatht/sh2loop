i=0
while [ "$i" -lt 3 ]; do
    i=$((i + 1))
    if [ "$i" -eq 2 ]; then
        continue
    fi
    echo "$i"
done
