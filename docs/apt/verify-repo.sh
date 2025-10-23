#!/bin/bash
# Repository verification script

echo "🔍 Verifying GH-Repos APT repository signatures..."

# Auto-detect script location and find repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If running from docs/apt/, the repo root is two levels up
if [[ "$(basename "$(dirname "$SCRIPT_DIR")")" == "docs" ]]; then
    REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
    APT_DIR="$SCRIPT_DIR"
else
    # If running from repo root, look for docs/apt/
    REPO_ROOT="$SCRIPT_DIR"
    APT_DIR="$REPO_ROOT/docs/apt"
fi

# Check if we can find the repository structure
if [[ ! -d "$APT_DIR/dists/stable" ]]; then
    echo "❌ Error: Repository not found"
    echo "💡 Expected structure: docs/apt/dists/stable/"
    echo "💡 Current APT dir: $APT_DIR"
    exit 1
fi

echo "📂 Repository root: $REPO_ROOT"
echo "📁 APT directory: $APT_DIR"

cd "$APT_DIR/dists/stable"

# Verify Release.gpg
if gpg --verify Release.gpg Release 2>/dev/null; then
    echo "✅ Release.gpg signature valid"
else
    echo "❌ Release.gpg signature invalid or key not imported"
    echo "💡 Import the repository key: gpg --import $REPO_ROOT/keys/apt-repo-pubkey.asc"
    exit 1
fi

# Verify InRelease
if gpg --verify InRelease 2>/dev/null; then
    echo "✅ InRelease signature valid"
else
    echo "❌ InRelease signature invalid"
    exit 1
fi

echo "🎉 Repository signatures verified successfully!"
