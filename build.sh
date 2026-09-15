#!/bin/bash
# Rebuilds the apt repository from the latest GitHub release of each repo in repos.txt.
# Needs: curl, dpkg-dev (dpkg-scanpackages), apt-utils (apt-ftparchive), gpg with the signing key.
# Env: GPG_HOMEDIR (default ~/.apt-repo/gnupg), GITHUB_TOKEN (optional, raises the API limit).
set -euo pipefail
cd "$(dirname "$0")"
OWNER=funkypitt
SUITE=stable
COMPONENT=main
ARCHES="amd64 arm64"
GPG_HOMEDIR="${GPG_HOMEDIR:-$HOME/.apt-repo/gnupg}"
KEY_ID="${KEY_ID:-pierregallaz@gmail.com}"
auth=()
[ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

# 1. Fetch the .deb files of the latest release of each repo into a fresh pool.
rm -rf pool dists
mkdir -p pool/$COMPONENT
while read -r repo; do
  [[ -z "$repo" || "$repo" == \#* ]] && continue
  echo "== $repo"
  json=$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$OWNER/$repo/releases/latest")
  urls=$(printf '%s' "$json" | grep -oE '"browser_download_url": *"[^"]+\.deb"' | grep -oE 'https://[^"]+')
  [ -n "$urls" ] || { echo "   no .deb in the latest release, skipped"; continue; }
  for url in $urls; do
    f=$(basename "$url"); tmp=$(mktemp)
    curl -fsSL "${auth[@]}" -o "$tmp" "$url"
    pkg=$(dpkg-deb -f "$tmp" Package); first=${pkg:0:1}
    mkdir -p "pool/$COMPONENT/$first/$pkg"; mv "$tmp" "pool/$COMPONENT/$first/$pkg/$f"; chmod 644 "pool/$COMPONENT/$first/$pkg/$f"
    echo "   $f ($(dpkg-deb -f "pool/$COMPONENT/$first/$pkg/$f" Version))"
  done
done < repos.txt

# 2. Packages indexes: one per architecture, the same "all" packages listed in each
#    (apt asks for its own architecture's index and expects arch-independent packages there).
for arch in $ARCHES; do
  d=dists/$SUITE/$COMPONENT/binary-$arch
  mkdir -p "$d"
  dpkg-scanpackages --multiversion --arch "$arch" pool > "$d/Packages" 2>/dev/null
  gzip -9nkf "$d/Packages"
done

# 3. Release file, signed inline (InRelease) and detached (Release.gpg).
apt-ftparchive \
  -o "APT::FTPArchive::Release::Origin=funkypitt" \
  -o "APT::FTPArchive::Release::Label=funkypitt" \
  -o "APT::FTPArchive::Release::Suite=$SUITE" \
  -o "APT::FTPArchive::Release::Codename=$SUITE" \
  -o "APT::FTPArchive::Release::Architectures=$ARCHES" \
  -o "APT::FTPArchive::Release::Components=$COMPONENT" \
  -o "APT::FTPArchive::Release::Description=Reader's apps for Linux (gallaz.ch/eink)" \
  release "dists/$SUITE" > "dists/$SUITE/Release"
gpg --homedir "$GPG_HOMEDIR" --batch --yes -u "$KEY_ID" --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
gpg --homedir "$GPG_HOMEDIR" --batch --yes -u "$KEY_ID" --detach-sign --armor -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"
gpg --homedir "$GPG_HOMEDIR" --export "$KEY_ID" > funkypitt.gpg
gpg --homedir "$GPG_HOMEDIR" --export --armor "$KEY_ID" > funkypitt.asc
touch .nojekyll
echo "done: $(grep -c ^Package: dists/$SUITE/$COMPONENT/binary-amd64/Packages) package(s)"
