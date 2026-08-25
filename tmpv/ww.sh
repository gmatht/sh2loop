text="a b c"
n=$(printf "%s" "$text" | wc -w)
echo "$n"
