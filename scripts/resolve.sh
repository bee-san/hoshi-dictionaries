#!/usr/bin/env bash
# Prints the upstream release tag each hosted dictionary currently resolves to, as
# {"<name>": "<tag>", ...}. Used by the workflow to decide whether a rebuild would
# produce anything new, and by build.sh to record what it built from.
set -euo pipefail

catalogue=${CATALOGUE:-dictionaries.json}

jq -r '.hosted[] | "\(.name)\t\(.repo)\t\(.release)"' "$catalogue" |
  while IFS=$'\t' read -r name repo release; do
    if [ "$release" = latest ]; then
      release=$(gh release view --repo "$repo" --json tagName -q .tagName)
    fi
    jq -n --arg name "$name" --arg tag "$release" '{($name): $tag}'
  done |
  jq -s 'add // {}'
