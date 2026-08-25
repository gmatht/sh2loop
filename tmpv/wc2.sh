text="a b  c\nd"
n=$(printf "%s" "$text" | wc -w)
echo "words=$n"
w=$(wc -w <<< "$text")
echo "direct=$w"
