#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

REPO_DIR="repo"
REPO_DIST="debian-podman"
REPO_COMP="main"

MAKEDEB="makedeb"
DPKG_SCAN="dpkg-scanpackages"
INSTALL=install
GZIP="gzip"
SHA256="sha256sum"
RM="rm -f"

exists () {
  [ -r "$1" ]
}

# update a built deb file in the repo
update () {
  local package="$1"
  if ! exists "$package/$package"*.deb; then
    echo "package $package not built"
    exit 1
  fi

  $RM "$REPO_DIR/pool/$REPO_COMP/$package"*.deb
  $INSTALL -Dt "$REPO_DIR/pool/$REPO_COMP/" "$package/$package"*.deb 
}

# build a package
build () {
  local package="$1"

  echo "building $package"
  (cd "$package" && $MAKEDEB -s)
  update "$package"
}

# generate release hash info
do_hash () {
  echo "SHA256:"

  for file in $(find -type f); do
    file=$(echo "$file" | cut -c3-) # remove ./ prefix
    if [ "$file" != "Release" ]; then
      echo " $($SHA256 "$file"  | cut -d" " -f1) $(wc -c "$file")"
    fi
  done
}

# generate a release manifest
release () {
  echo "Origin: debian-podman"
  echo "Label: debian-podman"
  echo "Architectures: amd64"
  echo "Suite: $REPO_DIST"
  echo "Codename: $REPO_DIST"
  echo "Components: $REPO_COMP"
  echo "Date: $(date -R -u)"

  (cd "$REPO_DIR/dists/$REPO_DIST" && do_hash)
}

# rescan packages and generate
# new repo metadata
rescan () {
  local packages="dists/$REPO_DIST/$REPO_COMP/binary-amd64"

  $INSTALL -d "$REPO_DIR/$packages"
  (cd "$REPO_DIR" && $DPKG_SCAN --arch amd64 "pool/$REPO_COMP" > "$packages/Packages")
  gzip -9 < "$REPO_DIR/$packages/Packages" > "$REPO_DIR/$packages/Packages.gz"

  release > "$REPO_DIR/dists/$REPO_DIST/Release"
}

if ! command -v "$MAKEDEB" 2>&1 >/dev/null; then
  echo "need makedeb to build packages"
  echo "install from https://docs.makedeb.org/"
  exit 1
fi

build crun
build podman

rescan

