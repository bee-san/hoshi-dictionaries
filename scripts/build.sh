#!/usr/bin/env bash
# Builds every hosted dictionary in dictionaries.json into a .hoshi container, plus the
# manifest, checksums and release notes published with them. Everything the workflow does,
# so this is the thing to run locally when CI breaks.
#
#   scripts/build.sh
#
# CLI=path/to/hoshidicts-cli   overrides the binary
# ONLY=jitendex,kanjidic2      builds a subset
# REUSE_ARCHIVES=1             keeps archives already downloaded into work/
set -euo pipefail

# always operate on the repository root so out/ and work/ land in a predictable place
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cli=${CLI:-./build/hoshidicts-cli}
catalogue=${CATALOGUE:-dictionaries.json}
# a jump past these means the container format moved and consumers would not understand it
allowed_payload_versions=${ALLOWED_PAYLOAD_VERSIONS:-3 4}

if [ ! -x "$cli" ]; then
  echo "no hoshidicts-cli at $cli; see the readme for how to build it" >&2
  exit 1
fi

rm -rf out
mkdir -p out work

resolved=$(CATALOGUE="$catalogue" scripts/resolve.sh)
printf '%s\n' "$resolved" > out/resolved.json

field() { awk -F': ' -v key="$1" '$1 == key { print $2; exit }' "$2"; }

jq -c --arg only "${ONLY:-}" '
  ($only | split(",")) as $names
  | .hosted[]
  | select($only == "" or (.name | IN($names[])))
' "$catalogue" | while IFS= read -r entry; do
  name=$(jq -r .name <<<"$entry")
  repo=$(jq -r .repo <<<"$entry")
  asset=$(jq -r .asset <<<"$entry")
  tag=$(jq -r --arg name "$name" '.[$name]' <<<"$resolved")

  echo
  echo "=== $name ($repo $tag) ==="

  dir=work/$name
  if [ -n "${REUSE_ARCHIVES:-}" ] && [ -f "$dir/$asset" ]; then
    echo "reusing $dir/$asset"
  else
    rm -rf "$dir"
    gh release download "$tag" --repo "$repo" --pattern "$asset" --dir "$dir" --clobber
  fi
  # drop any previous import so exactly one directory is left to find
  find "$dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

  "$cli" import "$dir/$asset" | tee "out/$name.import.txt"

  # the imported directory is found rather than derived: titles contain spaces and
  # brackets, as in "Jitendex.org [2026-08-11]"
  mapfile -t imported < <(find "$dir" -mindepth 1 -maxdepth 1 -type d)
  if [ "${#imported[@]}" -ne 1 ]; then
    echo "$name: expected exactly one imported directory, found ${#imported[@]}" >&2
    exit 1
  fi

  "$cli" pack "${imported[0]}" "out/$name.hoshi"
  "$cli" verify "out/$name.hoshi" | tee "out/$name.verify.txt"

  payload_version=$(field payload_version "out/$name.verify.txt")
  case " $allowed_payload_versions " in
    *" $payload_version "*) ;;
    *)
      echo "$name: payload version $payload_version is not one of: $allowed_payload_versions" >&2
      exit 1
      ;;
  esac

  zstd -19 -T0 -q -f "out/$name.hoshi" -o "out/$name.hoshi.zst"

  jq -n \
    --argjson entry "$entry" \
    --arg upstream_tag "$tag" \
    --argjson payload_version "$payload_version" \
    --argjson size "$(wc -c < "out/$name.hoshi")" \
    --arg sha256 "$(sha256sum "out/$name.hoshi" | cut -d' ' -f1)" \
    --argjson zst_size "$(wc -c < "out/$name.hoshi.zst")" \
    --arg zst_sha256 "$(sha256sum "out/$name.hoshi.zst" | cut -d' ' -f1)" \
    --argjson counts "$(jq -n \
      --argjson terms "$(field term_count "out/$name.import.txt")" \
      --argjson meta "$(field meta_count "out/$name.import.txt")" \
      --argjson freq "$(field freq_count "out/$name.import.txt")" \
      --argjson pitch "$(field pitch_count "out/$name.import.txt")" \
      --argjson kanji "$(field kanji_count "out/$name.import.txt")" \
      --argjson media "$(field media_count "out/$name.import.txt")" \
      '{$terms, $meta, $freq, $pitch, $kanji, $media}')" \
    '{
      name: $entry.name,
      title: $entry.title,
      kind: $entry.kind,
      license: $entry.license,
      homepage: $entry.homepage,
      upstream_repo: $entry.repo,
      $upstream_tag,
      upstream_asset: $entry.asset,
      $payload_version,
      $counts,
      file: "\($entry.name).hoshi.zst",
      $size,
      $sha256,
      $zst_size,
      $zst_sha256
    }' > "out/$name.manifest.json"
done

if ! ls out/*.manifest.json >/dev/null 2>&1; then
  echo "nothing was built" >&2
  exit 1
fi

(cd out && sha256sum ./*.hoshi.zst | sed 's| \./| |' > SHA256SUMS)

jq -n \
  --arg hoshidicts "$(git -C hoshidicts describe --tags --always)" \
  --argjson dictionaries "$(jq -s 'sort_by(.name)' out/*.manifest.json)" \
  '{$hoshidicts, $dictionaries}' > out/manifest.json
rm -f out/*.manifest.json

repository=${GITHUB_REPOSITORY:-bee-san/hoshi-dictionaries}
{
  echo "Recommended Yomitan dictionaries as single-file [\`.hoshi\`](https://github.com/Manhhao/hoshidicts#container-format) containers, ready to map and query with no import step."
  echo
  echo "| dictionary | kind | entries | download | upstream |"
  echo "| --- | --- | --- | --- | --- |"
  jq -r --arg repository "$repository" '
    def commas:
      tostring
      | [scan(".")] as $d
      | ($d | length) as $n
      | [range(0; $n) | $d[.] + (if ($n - . - 1) % 3 == 0 and (. < $n - 1) then "," else "" end)]
      | join("");
    def mb: (. / 100000 | round) / 10 | tostring;
    .dictionaries[] |
      "| [\(.title)](\(.homepage)) | \(.kind) "
      + "| \((if .kind == "kanji" then .counts.kanji else (.counts.terms + .counts.meta) end) | commas) "
      + "| [\(.file)](https://github.com/\($repository)/releases/latest/download/\(.file)) \(.zst_size | mb) MB "
      + "| `\(.upstream_tag)` |"
  ' out/manifest.json
  echo
  echo '```sh'
  echo "curl -LO https://github.com/$repository/releases/latest/download/jitendex.hoshi.zst"
  echo "zstd -d jitendex.hoshi.zst"
  echo "hoshidicts-cli verify jitendex.hoshi"
  echo '```'
  echo
  echo "Built with hoshidicts \`$(git -C hoshidicts describe --tags --always)\`. Checksums are in \`SHA256SUMS\`, and \`manifest.json\` carries every dictionary's upstream tag, payload version, entry counts and hashes. Gate on \`payload_version\`: a v4 container carries a trained zstd dictionary and needs an engine that knows about it."
  echo
  echo "Every dictionary here is **CC BY-SA 4.0** and these containers are format conversions"
  echo "that carry the same license. Attribution is required for redistribution; see"
  echo "[NOTICE.md](https://github.com/$repository/blob/main/NOTICE.md)."
  echo
  echo "Dictionaries that cannot be redistributed are listed in"
  echo "[\`dictionaries.json\`](https://github.com/$repository/blob/main/dictionaries.json);"
  echo "\`scripts/pack.sh <your.zip>\` converts your own copy."
} > out/notes.md

echo
echo "wrote:"
ls -l out
