#!/bin/bash
# Script to squash all commits into one while preserving the v1.0.5 tag

set -e

echo "WARNING: This will rewrite history and force push!"
echo "Make sure you have a backup of your repository."
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Get the root commit
ROOT_COMMIT=$(git rev-list --max-parents=0 HEAD)
echo "Root commit: $ROOT_COMMIT"

# Create a new branch for safety
git checkout -b squash-temp

# Reset to the root commit but keep all changes
git reset --soft $ROOT_COMMIT

# Create a new single commit with all changes
git commit -m "Stheno Embedded Toolkit v1.0.5

Complete embedded toolkit for building static debugging tools across 32 architectures.

Features:
- Support for 32 different architectures
- Static binaries with musl libc
- Tools: strace, busybox, bash, socat, ncat, tcpdump, gdbserver, gdb, nmap
- Docker-based build system
- Automated dependency management
- GitHub Actions CI/CD for releases

Recent fixes:
- Fixed ARMv7-R float ABI from softfp to hard to match toolchain
- Removed explicit -mabi=n32 from MIPS N32 architectures to fix ABI conflicts
- Resolved VFP register argument mismatches and MIPS linker crashes

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Force move the tag to the new commit
git tag -f v1.0.5

# Force push to main
echo "Ready to force push. This will rewrite history!"
echo "Command to run: git push --force origin squash-temp:main"
echo "Command to push tag: git push --force origin v1.0.5"
echo
echo "Run these commands manually when ready."