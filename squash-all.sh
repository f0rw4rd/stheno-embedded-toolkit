#!/bin/bash
# Squash all commits into one

set -e

echo "Creating squashed commit..."

# Get the initial commit
FIRST_COMMIT=$(git rev-list --max-parents=0 HEAD)

# Create a backup branch just in case
git branch backup-before-squash || true

# Reset to first commit keeping all files
git reset --soft $FIRST_COMMIT

# Create new commit with all changes
git commit -m "Stheno Embedded Toolkit v1.0.6"

# Force move tag to new commit
git tag -f v1.0.6

echo "Done! Squashed all commits into one."
echo
echo "To push (THIS WILL REWRITE HISTORY):"
echo "  git push --force origin main"
echo "  git push --force origin v1.0.5"
echo
echo "Backup branch 'backup-before-squash' was created for safety"
