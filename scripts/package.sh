#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
root=$PWD
version=$(head -n 1 VERSION)
mkdir -p .work binaries
work=$(mktemp -d "$root/.work/package.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/odin_ui"
cp -R src/layout src/text src/input src/raylib "$work/odin_ui/"
cp LICENSE VERSION MIGRATING.md "$work/odin_ui/"
cp VENDORING.md "$work/odin_ui/README.md"
filename="odin_ui-v$version.zip"
archive="$root/binaries/$filename"
# Prepare and verify privately; preparation failures leave the previous archive intact.
(cd "$work" && zip -qr "$filename" odin_ui && unzip -tq "$filename" >/dev/null)
(
    cd "$work"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$filename"
    else
        shasum -a 256 "$filename"
    fi
) > "$work/SHA256SUMS.txt"
mv "$work/$filename" "$archive"
mv "$work/SHA256SUMS.txt" "$root/binaries/SHA256SUMS.txt"
printf '%s\n' "$archive"
