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
cp LICENSE VERSION "$work/odin_ui/"
cp VENDORING.md "$work/odin_ui/README.md"
archive="$root/binaries/odin_ui-v$version.zip"
# Start a new archive so removed source files cannot survive an earlier build.
rm -f "$archive"
(cd "$work" && zip -qr "$archive" odin_ui)
printf '%s\n' "$archive"
