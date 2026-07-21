#!/bin/bash
# Update the blessed commit hash in ensure_examples_snapshot.pl
# to the current HEAD of the sh2perl repo.
set -e

cd "$(dirname "$0")"

NEW_HASH=$(cd sh2perl && git rev-parse HEAD)
sed -i "s/my \$blessed_commit = '.*';/my \$blessed_commit = '$NEW_HASH';/" ensure_examples_snapshot.pl

echo "Blessed commit updated to $NEW_HASH"
