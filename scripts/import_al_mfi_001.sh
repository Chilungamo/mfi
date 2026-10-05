#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# AL-MFI-001 v0.2 — Import into Git repository
# ============================================================

TARGET_REPO="$(pwd)"

echo "=============================================="
echo " AL-MFI-001 v0.2 Git Import"
echo "=============================================="
echo
echo "Target Git repository:"
echo "$TARGET_REPO"
echo

# ------------------------------------------------------------
# 1. Verify this is a Git repository
# ------------------------------------------------------------

if [ ! -d "$TARGET_REPO/.git" ]; then
    echo "ERROR: This directory is not a Git repository:"
    echo "$TARGET_REPO"
    exit 1
fi

# ------------------------------------------------------------
# 2. Ask for location of the AL-MFI-001 source folder
# ------------------------------------------------------------

read -rp "Enter the path to the AL-MFI-001 source folder: " SOURCE_DIR

# Remove surrounding quotes if pasted
SOURCE_DIR="${SOURCE_DIR%\"}"
SOURCE_DIR="${SOURCE_DIR#\"}"

if [ ! -d "$SOURCE_DIR" ]; then
    echo
    echo "ERROR: Source directory does not exist:"
    echo "$SOURCE_DIR"
    exit 1
fi

echo
echo "Source:"
echo "$SOURCE_DIR"

# ------------------------------------------------------------
# 3. Copy complete directory tree
# ------------------------------------------------------------

echo
echo "Copying complete AL-MFI-001 directory structure..."

rsync -av \
    --exclude='.git/' \
    --exclude='__pycache__/' \
    --exclude='.pytest_cache/' \
    --exclude='.venv/' \
    --exclude='venv/' \
    --exclude='*.pyc' \
    "$SOURCE_DIR"/ \
    "$TARGET_REPO"/

# ------------------------------------------------------------
# 4. Display resulting structure
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Repository structure"
echo "=============================================="

find . \
    -not -path './.git*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.pytest_cache/*' \
    -print | sort

# ------------------------------------------------------------
# 5. Git status
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Git status"
echo "=============================================="

git status --short

# ------------------------------------------------------------
# 6. Stage everything
# ------------------------------------------------------------

echo
echo "Staging files..."

git add .

# ------------------------------------------------------------
# 7. Show staged files
# ------------------------------------------------------------

echo
echo "=============================================="
echo " Files staged for commit"
echo "=============================================="

git diff --cached --name-status

# ------------------------------------------------------------
# 8. Commit
# ------------------------------------------------------------

echo
read -rp "Create AL-MFI-001 v0.2 commit? [y/N]: " COMMIT

if [[ "$COMMIT" =~ ^[Yy]$ ]]; then

    git commit -m "feat: add AL-MFI-001 v0.2 repository structure"

    echo
    echo "Commit created successfully."

else

    echo
    echo "Commit skipped."

fi

# ------------------------------------------------------------
# 9. Push
# ------------------------------------------------------------

echo
read -rp "Push to origin now? [y/N]: " PUSH

if [[ "$PUSH" =~ ^[Yy]$ ]]; then

    BRANCH="$(git branch --show-current)"

    git push -u origin "$BRANCH"

    echo
    echo "Successfully pushed to origin/$BRANCH."

else

    echo
    echo "Push skipped."
    echo
    echo "You can push later with:"
    echo
    echo "    git push -u origin $(git branch --show-current)"

fi

echo
echo "=============================================="
echo " AL-MFI-001 v0.2 import complete"
echo "=============================================="
