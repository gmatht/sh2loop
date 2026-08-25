line="one two three four"
count=0
for w in $line; do
  count=$((count+1))
done
echo "words=$count"
