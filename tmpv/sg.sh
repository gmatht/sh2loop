a=$(date)
b=$(hostname)
fn() { echo "$a $b"; }
fn
echo "after: $a"
