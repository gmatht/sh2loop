x=10
if [ "$x" -gt 100 ]; then
    echo "large"
elif [ "$x" -gt 5 ]; then
    echo "medium"
else
    echo "small"
fi
