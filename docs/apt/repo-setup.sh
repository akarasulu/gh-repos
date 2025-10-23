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
