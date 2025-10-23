#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: prepare-template.sh <repository-url> [target-directory]

Clone your fork of gh-repos, reset MkDocs content to placeholders,
regenerate the static site, and export a selected GPG public key.

Arguments:
  <repository-url>   SSH or HTTPS URL of your fork (required).
  [target-directory] Optional destination directory for the clone. Defaults to
                     the repository name derived from the URL.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if ! command -v git >/dev/null 2>&1; then
    echo "git is required but was not found in PATH." >&2
    exit 1
fi

if ! command -v gpg >/dev/null 2>&1; then
    echo "gpg is required but was not found in PATH." >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    read -rp "Repository URL for your fork (e.g. git@github.com:user/gh-repos.git): " repo_url
    if [[ -z "${repo_url}" ]]; then
        echo "Repository URL is required." >&2
        usage >&2
        exit 1
    fi
else
    repo_url="$1"
fi

derive_dir_name() {
    local url="$1"
    local trimmed="${url%%.git}"
    trimmed="${trimmed%/}"
    echo "${trimmed##*/}"
}

target_dir="${2:-$(derive_dir_name "$repo_url")}"

if [[ -z "$target_dir" ]]; then
    echo "Unable to determine target directory name. Please specify it explicitly." >&2
    exit 1
fi

if [[ -e "$target_dir" ]]; then
    echo "Target directory '$target_dir' already exists. Choose another name or remove it." >&2
    exit 1
fi

echo "📦 Cloning $repo_url into $target_dir ..."
git clone --origin origin "$repo_url" "$target_dir"

cd "$target_dir"

if [[ ! -d "templates/mkdocs" ]]; then
    echo "templates/mkdocs directory not found in the cloned repository." >&2
    exit 1
fi

echo "🧹 Resetting MkDocs source content..."
rm -rf mkdocs/*
cp -R templates/mkdocs/. mkdocs/

echo "🧽 Clearing generated docs and previous APT repository..."
rm -rf docs

if [[ ! -x "./scripts/mkdocs.sh" ]]; then
    echo "scripts/mkdocs.sh is missing or not executable." >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to rebuild documentation." >&2
    exit 1
fi

echo "🏗️ Rebuilding documentation with placeholder content..."
./scripts/mkdocs.sh

echo "🔐 Discovering available GPG private keys..."
mapfile -t gpg_lines < <(gpg --list-secret-keys --with-colons 2>/dev/null || true)

declare -a fingerprints=()
declare -a labels=()
current_fpr=""

for line in "${gpg_lines[@]}"; do
    IFS=':' read -ra parts <<<"$line"
    type="${parts[0]}"
    case "$type" in
        fpr)
            current_fpr="${parts[9]}"
            ;;
        uid)
            if [[ -n "$current_fpr" ]]; then
                fingerprints+=("$current_fpr")
                labels+=("${parts[9]}")
                current_fpr=""
            fi
            ;;
    esac
done

if [[ ${#fingerprints[@]} -eq 0 ]]; then
    echo "No GPG private keys were found. Create one with 'gpg --full-generate-key' and rerun this script." >&2
    exit 1
fi

echo "Available keys:"
for i in "${!fingerprints[@]}"; do
    printf "  [%d] %s\n      %s\n" "$((i + 1))" "${labels[$i]}" "${fingerprints[$i]}"
done

selection=""
while [[ -z "$selection" ]]; do
    read -rp "Select a key to export [1-${#fingerprints[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#fingerprints[@]} )); then
        selection=$((choice - 1))
    else
        echo "Invalid selection. Please choose a number between 1 and ${#fingerprints[@]}."
    fi
done

mkdir -p keys docs/apt
fingerprint="${fingerprints[$selection]}"

echo "📝 Exporting public key for ${labels[$selection]}..."
gpg --armor --export "$fingerprint" > keys/apt-repo-pubkey.asc
cp keys/apt-repo-pubkey.asc docs/apt/apt-repo-pubkey.asc

cat <<EOF
✅ Template preparation complete.

Next steps:
  1. cd $target_dir
  2. Review placeholder docs in mkdocs/.
  3. Update packages or scripts as needed.
  4. Run ./scripts/mkdocs.sh and ./scripts/mkrepo.sh after customizing.
  5. git status && git commit -am "Customize template"
EOF
