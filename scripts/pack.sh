#!/usr/bin/env bash
# Turns any Yomitan dictionary zip into a .hoshi container. This is the path for the
# dictionaries this repository cannot publish: bring your own zip.
#
#   scripts/pack.sh ~/Downloads/大辞林.zip
#   scripts/pack.sh ~/Downloads/大辞林.zip daijirin.hoshi
#
# CLI=path/to/hoshidicts-cli overrides the binary.
set -euo pipefail

zip=${1:?usage: scripts/pack.sh <dictionary.zip> [output.hoshi]}
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cli=${CLI:-$root/build/hoshidicts-cli}

if [ ! -x "$cli" ]; then
  echo "no hoshidicts-cli at $cli; see the readme for how to build it" >&2
  exit 1
fi
if [ ! -f "$zip" ]; then
  echo "no such file: $zip" >&2
  exit 1
fi

name=$(basename "$zip")
output=${2:-${name%.zip}.hoshi}

# the importer writes next to the zip it is handed, so give it a symlink in a scratch
# directory instead of littering the caller's
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ln -s "$(cd "$(dirname "$zip")" && pwd)/$name" "$work/$name"

"$cli" import "$work/$name"

mapfile -t imported < <(find "$work" -mindepth 1 -maxdepth 1 -type d)
if [ "${#imported[@]}" -ne 1 ]; then
  echo "expected exactly one imported directory, found ${#imported[@]}" >&2
  exit 1
fi

"$cli" pack "${imported[0]}" "$output"
"$cli" verify "$output"
echo "wrote $output"
