#!/usr/bin/env bash
set -euo pipefail

# signrepo.sh - GPG sign APT repository files and artifacts
# This script runs on the HOST where GPG keys are securely configured

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
APT_REPO_DIR="$WORKSPACE_ROOT/docs/apt"

echo "🔐 Signing APT repository with GPG..."
echo "════════════════════════════════════"

# Check if APT repository exists
if [[ ! -d "$APT_REPO_DIR" ]]; then
    echo "❌ Error: APT repository not found at $APT_REPO_DIR"
    echo "💡 Run build.sh first to create the repository"
    exit 1
fi

# Check if Release file exists
release_file="$APT_REPO_DIR/dists/stable/Release"
if [[ ! -f "$release_file" ]]; then
    echo "❌ Error: Release file not found at $release_file"
    echo "💡 Run mkrepo.sh to create repository metadata"
    exit 1
fi

# Check if GPG is available
if ! command -v gpg &> /dev/null; then
    echo "❌ Error: GPG is not installed or not in PATH"
    echo "💡 Please install GnuPG to sign the repository"
    exit 1
fi

# Get GPG key ID (allow user to specify or auto-detect)
if [[ -n "${GPG_KEY_ID:-}" ]]; then
    echo "🔑 Using specified GPG key: $GPG_KEY_ID"
    key_id="$GPG_KEY_ID"
elif [[ -n "${GPG_SIGNING_KEY:-}" ]]; then
    echo "🔑 Using GPG signing key: $GPG_SIGNING_KEY"
    key_id="$GPG_SIGNING_KEY"
else
    echo "🔍 Auto-detecting GPG key..."
    
    # Get list of secret keys
    secret_keys=$(gpg --list-secret-keys --with-colons | grep '^sec:' | cut -d: -f5)
    
    if [[ -z "$secret_keys" ]]; then
        echo "❌ Error: No GPG secret keys found"
        echo "💡 Create a GPG key with: gpg --full-generate-key"
        exit 1
    fi
    
    # Use the first available key
    key_id=$(echo "$secret_keys" | head -1)
    echo "🔑 Using auto-detected key: $key_id"
fi

# Verify the key exists and can be used
if ! gpg --list-secret-keys "$key_id" &> /dev/null; then
    echo "❌ Error: GPG key $key_id not found or not accessible"
    echo "💡 Available keys:"
    gpg --list-secret-keys --keyid-format SHORT
    exit 1
fi

# Get key details for confirmation
key_info=$(gpg --list-keys --with-colons "$key_id" | grep '^uid:' | head -1 | cut -d: -f10)
echo "📋 Key details: $key_info"

# Confirm signing (allow override with environment variable)
if [[ "${GPG_SIGN_CONFIRM:-true}" == "true" ]]; then
    echo ""
    read -p "🤔 Sign repository with this key? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Signing cancelled by user"
        exit 1
    fi
fi

echo ""
echo "🔏 Starting repository signing process..."

# Sign individual .deb packages
echo "📦 Signing individual packages..."
package_count=0
signed_packages=0

for deb_file in "$APT_REPO_DIR/pool"/*.deb; do
    if [[ -f "$deb_file" ]]; then
        ((package_count++))
        package_name=$(basename "$deb_file")
        
        echo "   Signing: $package_name"
        
        # Remove existing signature if present
        rm -f "$deb_file.asc"
        
        # Create detached signature
        if gpg --detach-sign --armor --local-user "$key_id" --output "$deb_file.asc" "$deb_file"; then
            echo "   ✅ Signed: $package_name"
            ((signed_packages++))
        else
            echo "   ❌ Failed to sign: $package_name"
        fi
    fi
done

echo "📊 Package signing: $signed_packages/$package_count packages signed"

# Sign repository Release file
echo ""
echo "📄 Signing Release file..."

cd "$APT_REPO_DIR/dists/stable"

# Remove existing signatures
rm -f Release.gpg InRelease

# Create detached signature (Release.gpg)
if gpg --detach-sign --armor --local-user "$key_id" --output Release.gpg Release; then
    echo "✅ Created Release.gpg signature"
else
    echo "❌ Failed to create Release.gpg signature"
    exit 1
fi

# Create inline signature (InRelease)
if gpg --clearsign --local-user "$key_id" --output InRelease Release; then
    echo "✅ Created InRelease signature"
else
    echo "❌ Failed to create InRelease signature"
    exit 1
fi

cd "$WORKSPACE_ROOT"

# Verify signatures
echo ""
echo "🔍 Verifying signatures..."

# Verify Release.gpg
if gpg --verify "$APT_REPO_DIR/dists/stable/Release.gpg" "$APT_REPO_DIR/dists/stable/Release" &> /dev/null; then
    echo "✅ Release.gpg signature verified"
else
    echo "❌ Release.gpg signature verification failed"
    exit 1
fi

# Verify InRelease
if gpg --verify "$APT_REPO_DIR/dists/stable/InRelease" &> /dev/null; then
    echo "✅ InRelease signature verified"
else
    echo "❌ InRelease signature verification failed"
    exit 1
fi

# Update repository index with signing information
cat > "$APT_REPO_DIR/SIGNED" << EOF
Repository signed on: $(date -Ru)
GPG Key ID: $key_id
Key fingerprint: $(gpg --fingerprint "$key_id" | grep fingerprint | head -1 | sed 's/.*= //')
Signed packages: $signed_packages
Total packages: $package_count
EOF

# Create verification script for users
cat > "$APT_REPO_DIR/verify-repo.sh" << EOF
#!/bin/bash
# Repository verification script

echo "🔍 Verifying GH-Repos APT repository signatures..."

REPO_DIR="\${1:-.}"
if [[ ! -d "\$REPO_DIR/dists/stable" ]]; then
    echo "❌ Error: Repository not found in \$REPO_DIR"
    exit 1
fi

cd "\$REPO_DIR/dists/stable"

# Verify Release.gpg
if gpg --verify Release.gpg Release 2>/dev/null; then
    echo "✅ Release.gpg signature valid"
else
    echo "❌ Release.gpg signature invalid or key not imported"
    echo "💡 Import the repository key first"
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
EOF

chmod +x "$APT_REPO_DIR/verify-repo.sh"

echo ""
echo "🎉 Repository signing completed successfully!"
echo "═══════════════════════════════════════════"
echo "✅ Signed packages: $signed_packages/$package_count"
echo "✅ Release file signed (Release.gpg + InRelease)"
echo "🔑 Used key: $key_id"
echo ""
echo "📂 Generated signature files:"
echo "   - Release.gpg (detached signature)"
echo "   - InRelease (inline signature)"
echo "   - *.deb.asc (package signatures)"
echo "   - SIGNED (signing summary)"
echo "   - verify-repo.sh (verification script)"
echo ""
echo "🔐 Repository is now cryptographically signed!"
echo "💡 Users can verify with: bash verify-repo.sh"

