#!/bin/bash
# Heredoc with single quotes in body — tests the spanning-token fix
cat > /tmp/test.py << 'EOF'
x = 'hello'
print(f'value: {x}')
EOF
echo "done"
