#!/usr/bin/env bash
set -euo pipefail

# mkdocs.sh - Generate GitHub Pages website using MkDocs
# This script runs inside the Debian 12 container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$WORKSPACE_ROOT/docs"
MKDOCS_DIR="$WORKSPACE_ROOT/mkdocs"

echo "🏗️  Generating GitHub Pages website with MkDocs..."

# Ensure we're in the workspace root
cd "$WORKSPACE_ROOT"

# Check if mkdocs.yml exists
if [[ ! -f "mkdocs.yml" ]]; then
    echo "❌ Error: mkdocs.yml not found in workspace root"
    exit 1
fi

# Check if mkdocs source directory exists
if [[ ! -d "$MKDOCS_DIR" ]]; then
    echo "❌ Error: mkdocs source directory not found at $MKDOCS_DIR"
    exit 1
fi

# Install mkdocs and dependencies if not already installed
echo "📦 Checking MkDocs installation..."
if ! command -v mkdocs &> /dev/null; then
    echo "Installing MkDocs and dependencies..."
    pip3 install --user mkdocs mkdocs-material pymdown-extensions
    export PATH="$HOME/.local/bin:$PATH"
fi

# Clean existing docs directory (but preserve apt/ subdirectory if it exists)
echo "🧹 Cleaning docs directory (preserving apt/ if exists)..."
if [[ -d "$DOCS_DIR" ]]; then
    # Preserve apt directory if it exists
    if [[ -d "$DOCS_DIR/apt" ]]; then
        echo "💾 Preserving existing apt/ directory..."
        mv "$DOCS_DIR/apt" "$DOCS_DIR.apt.backup" 2>/dev/null || true
    fi
    
    # Remove everything else
    rm -rf "$DOCS_DIR"/*
    
    # Restore apt directory if we backed it up
    if [[ -d "$DOCS_DIR.apt.backup" ]]; then
        mkdir -p "$DOCS_DIR"
        mv "$DOCS_DIR.apt.backup" "$DOCS_DIR/apt"
    fi
else
    mkdir -p "$DOCS_DIR"
fi

# Build the site
echo "🔨 Building MkDocs site..."
mkdocs build --clean --strict

# Verify the build
if [[ ! -f "$DOCS_DIR/index.html" ]]; then
    echo "❌ Error: MkDocs build failed - no index.html generated"
    exit 1
fi

# Create .nojekyll file to prevent GitHub Pages from processing with Jekyll
touch "$DOCS_DIR/.nojekyll"

# Display build summary
echo "✅ MkDocs build completed successfully!"
echo "📁 Generated files in: $DOCS_DIR"
echo "📊 Build summary:"
echo "   - HTML files: $(find "$DOCS_DIR" -name "*.html" | wc -l)"
echo "   - CSS files: $(find "$DOCS_DIR" -name "*.css" | wc -l)"
echo "   - JS files: $(find "$DOCS_DIR" -name "*.js" | wc -l)"

if [[ -d "$DOCS_DIR/apt" ]]; then
    echo "   - APT repo preserved: Yes"
else
    echo "   - APT repo preserved: No (will be created by mkrepo.sh)"
fi

echo "🎉 Website ready for GitHub Pages deployment!"