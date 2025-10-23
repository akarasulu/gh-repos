#!/usr/bin/env bash
set -euo pipefail

# mkrepo.sh - Create APT repository structure under /docs/apt
# This script runs inside the Debian 12 container

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
DOCS_DIR="$WORKSPACE_ROOT/docs"
APT_REPO_DIR="$DOCS_DIR/apt"
DEB_OUTPUT_DIR="$WORKSPACE_ROOT/debs"
KEYS_DIR="$WORKSPACE_ROOT/keys"

echo "🏗️  Creating APT repository structure..."

# Create APT repository directories
mkdir -p "$APT_REPO_DIR"/{pool,dists/stable/{main/{binary-amd64,binary-arm64,binary-all,source}}}

# Check if we have packages to include
if [[ ! -d "$DEB_OUTPUT_DIR" ]] || [[ -z "$(ls -A "$DEB_OUTPUT_DIR"/*.deb 2>/dev/null || true)" ]]; then
    echo "❌ Error: No .deb packages found in $DEB_OUTPUT_DIR"
    echo "💡 Run mkdebs.sh first to build packages"
    exit 1
fi

# Copy .deb packages to pool directory
echo "📦 Copying packages to repository pool..."
package_count=0
for deb_file in "$DEB_OUTPUT_DIR"/*.deb; do
    if [[ -f "$deb_file" ]]; then
        cp "$deb_file" "$APT_REPO_DIR/pool/"
        echo "   - $(basename "$deb_file")"
        package_count=$((package_count + 1))
    fi
done

echo "✅ Copied $package_count packages to repository pool"

# Copy GPG public key
echo "🔑 Adding GPG public key to repository..."
if [[ -f "$KEYS_DIR/apt-repo-pubkey.asc" ]]; then
    cp "$KEYS_DIR/apt-repo-pubkey.asc" "$APT_REPO_DIR/"
    echo "✅ GPG public key added"
else
    echo "⚠️  Warning: GPG public key not found at $KEYS_DIR/apt-repo-pubkey.asc"
    echo "💡 Users will need to manually import your key or add it later"
fi

# Create repository metadata
echo "📋 Generating repository metadata..."

# Function to create Packages file for a specific architecture
create_packages_file() {
    local arch="$1"
    local packages_dir="$APT_REPO_DIR/dists/stable/main/binary-$arch"
    local packages_file="$packages_dir/Packages"
    
    mkdir -p "$packages_dir"
    
    echo "   Creating Packages file for $arch..."
    
    # Clear the Packages file
    > "$packages_file"
    
    # Process each .deb file
    for deb_file in "$APT_REPO_DIR/pool"/*.deb; do
        if [[ -f "$deb_file" ]]; then
            # Get package architecture from the .deb file
            pkg_arch=$(dpkg-deb -f "$deb_file" Architecture)
            
            # Include package if architecture matches or is 'all'
            if [[ "$pkg_arch" == "$arch" ]] || [[ "$pkg_arch" == "all" && "$arch" == "amd64" ]]; then
                # Extract package info
                dpkg-deb -f "$deb_file" >> "$packages_file"
                
                # Add additional metadata
                filename="pool/$(basename "$deb_file")"
                size=$(stat -c%s "$deb_file")
                md5sum=$(md5sum "$deb_file" | cut -d' ' -f1)
                sha1sum=$(sha1sum "$deb_file" | cut -d' ' -f1)
                sha256sum=$(sha256sum "$deb_file" | cut -d' ' -f1)
                
                echo "Filename: $filename" >> "$packages_file"
                echo "Size: $size" >> "$packages_file"
                echo "MD5sum: $md5sum" >> "$packages_file"
                echo "SHA1: $sha1sum" >> "$packages_file"
                echo "SHA256: $sha256sum" >> "$packages_file"
                echo "" >> "$packages_file"
            fi
        fi
    done
    
    # Compress the Packages file
    gzip -c "$packages_file" > "$packages_file.gz"
    
    # Create Packages.bz2 if bzip2 is available
    if command -v bzip2 &> /dev/null; then
        bzip2 -c "$packages_file" > "$packages_file.bz2"
    fi
}

# Create Packages files for different architectures
create_packages_file "amd64"
create_packages_file "arm64"
create_packages_file "all"

# Create Release file
echo "📄 Creating Release file..."
release_file="$APT_REPO_DIR/dists/stable/Release"

cat > "$release_file" << EOF
Origin: GH-Repos
Label: GH-Repos APT Repository
Suite: stable
Version: 1.0
Codename: stable
Date: $(date -Ru)
Architectures: amd64 arm64 all
Components: main
Description: APT repository hosted on GitHub Pages
EOF

# Calculate checksums for Release file
echo "MD5Sum:" >> "$release_file"
(cd "$APT_REPO_DIR/dists/stable" && find . -type f -name "Packages*" -exec md5sum {} \; | sed 's/\.\///') >> "$release_file"

echo "SHA1:" >> "$release_file"
(cd "$APT_REPO_DIR/dists/stable" && find . -type f -name "Packages*" -exec sha1sum {} \; | sed 's/\.\///') >> "$release_file"

echo "SHA256:" >> "$release_file"
(cd "$APT_REPO_DIR/dists/stable" && find . -type f -name "Packages*" -exec sha256sum {} \; | sed 's/\.\///') >> "$release_file"

# Create repository configuration file for users
echo "📝 Creating repository configuration..."
cat > "$APT_REPO_DIR/repo-setup.sh" << 'EOF'
#!/bin/bash
# Repository setup script for users

REPO_URL="https://$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1).github.io/$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)"

echo "Adding GH-Repos APT repository..."

# Download and add GPG key
curl -fsSL "$REPO_URL/apt/apt-repo-pubkey.asc" | sudo apt-key add -

# Add repository to sources
echo "deb $REPO_URL/apt stable main" | sudo tee /etc/apt/sources.list.d/gh-repos.list

# Update package list
sudo apt update

echo "Repository added successfully!"
echo "Install packages with: sudo apt install <package-name>"
EOF

chmod +x "$APT_REPO_DIR/repo-setup.sh"

# Create a simple index.html for the APT repository
cat > "$APT_REPO_DIR/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>GH-Repos APT Repository</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        pre { background: #f4f4f4; padding: 10px; border-radius: 5px; }
        .package { margin: 10px 0; padding: 10px; border: 1px solid #ddd; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>GH-Repos APT Repository</h1>
        <p>This is an APT repository hosted on GitHub Pages.</p>
        
        <h2>Quick Setup</h2>
        <pre><code># Download and run setup script
curl -fsSL \$(echo \$REPO_URL)/apt/repo-setup.sh | bash

# Or manual setup:
curl -fsSL \$(echo \$REPO_URL)/apt/apt-repo-pubkey.asc | sudo apt-key add -
echo "deb \$(echo \$REPO_URL)/apt stable main" | sudo tee /etc/apt/sources.list.d/gh-repos.list
sudo apt update</code></pre>

        <h2>Available Packages</h2>
        <div id="packages">
EOF

# List available packages in the HTML
for deb_file in "$APT_REPO_DIR/pool"/*.deb; do
    if [[ -f "$deb_file" ]]; then
        pkg_name=$(dpkg-deb -f "$deb_file" Package)
        pkg_version=$(dpkg-deb -f "$deb_file" Version)
        pkg_description=$(dpkg-deb -f "$deb_file" Description || echo "No description available")
        
        cat >> "$APT_REPO_DIR/index.html" << EOF
            <div class="package">
                <h3>$pkg_name ($pkg_version)</h3>
                <p>$pkg_description</p>
                <code>sudo apt install $pkg_name</code>
            </div>
EOF
    fi
done

cat >> "$APT_REPO_DIR/index.html" << EOF
        </div>
    </div>
</body>
</html>
EOF

# Display repository summary
echo ""
echo "📊 APT Repository Summary"
echo "═════════════════════════"
echo "📍 Repository location: $APT_REPO_DIR"
echo "📦 Packages: $package_count"
echo ""
echo "📂 Repository structure:"
find "$APT_REPO_DIR" -type f | sort | sed 's|^'"$APT_REPO_DIR"'|   apt|'

echo ""
echo "✅ APT repository created successfully!"
echo "🔐 Note: Repository metadata is unsigned - run signrepo.sh on host to sign"
echo "🌐 Repository will be available at: https://username.github.io/repo-name/apt/"