#!/bin/sh
set -eu
project=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)
if [ "${PROJECT_ROOT:-}" != "$project" ] || [ -z "${PROJECT_NIX_ENVIRONMENT:-}" ]; then
    exec "$project/scripts/dev" "$project/scripts/package.sh" "$@"
fi
cd "$project"
root=$PWD
version=$(head -n 1 VERSION)
python3 -I tools/check_publication.py src LICENSE VERSION MIGRATING.md VENDORING.md
mkdir -p .work/package
work=$(mktemp -d "$root/.work/package/stage.XXXXXX")
trap 'rm -rf "$work"' EXIT
mkdir "$work/odin_ui"
cp -R src/layout src/text src/input src/raylib "$work/odin_ui/"
cp LICENSE VERSION MIGRATING.md "$work/odin_ui/"
cp VENDORING.md "$work/odin_ui/README.md"
filename="odin_ui-v$version.zip"
archive="$root/.work/package/$filename"
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
mv "$work/SHA256SUMS.txt" "$root/.work/package/SHA256SUMS.txt"
printf '%s\n' "$archive"
