#!/bin/bash
# Repository setup script for users

REPO_URL="https://$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1).github.io/$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)"

echo "🔧 Adding GH-Repos APT repository..."

# Check if we're on a system that supports the modern method
if [[ -d "/etc/apt/trusted.gpg.d" ]]; then
    echo "📥 Downloading and installing GPG key..."
    # Download GPG key to trusted.gpg.d (modern method)
    curl -fsSL "$REPO_URL/apt/apt-repo-pubkey.asc" | sudo tee /etc/apt/trusted.gpg.d/gh-repos.asc > /dev/null
    echo "✅ GPG key installed to /etc/apt/trusted.gpg.d/gh-repos.asc"
else
    echo "📥 Downloading and installing GPG key (legacy method)..."
    # Fallback to apt-key for older systems
    curl -fsSL "$REPO_URL/apt/apt-repo-pubkey.asc" | sudo apt-key add -
    echo "✅ GPG key added via apt-key"
fi

echo "📝 Adding repository to sources..."
# Add repository to sources
echo "deb $REPO_URL/apt stable main" | sudo tee /etc/apt/sources.list.d/gh-repos.list

echo "🔄 Updating package list..."
# Update package list
sudo apt update

echo "🎉 Repository added successfully!"
echo "📦 Install packages with: sudo apt install <package-name>"
echo "📋 Available packages: hello-world, dev-tools, mock-monitor, sys-info"
