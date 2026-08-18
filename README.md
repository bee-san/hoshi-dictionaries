# hoshi-dictionaries

Japanese dictionaries as single-file
[`.hoshi`](https://github.com/Manhhao/hoshidicts/blob/main/docs/hoshi-container-v1.md)
containers, rebuilt monthly.

A `.hoshi` file is the directory a [hoshidicts](https://github.com/Manhhao/hoshidicts) import
produces, concatenated behind a header and a section table. Loading one is a single `mmap` and
a small `index.json` parse, so there is no import on the user's device: no JSON parsing, no
zstd training, no index building, no peak-RAM spike, no half-finished import to recover from,
and identical bytes everywhere. On Jitendex that replaces a measured 574 ms import with a
0.05 ms open. Lookup speed is unchanged by design — same blobs, same hash table, same bloom
filter, same code path.

## Downloads

Asset names carry no version, so these URLs always point at the newest build:

| dictionary | kind | entries | download |
| --- | --- | --- | --- |
| [Jitendex](https://jitendex.org) | term | 435,448 | [`jitendex.hoshi.zst`](../../releases/latest/download/jitendex.hoshi.zst) — 54 MB |
| [JMdict (English)](https://www.edrdg.org/jmdict/j_jmdict.html) | term | 526,257 | [`jmdict-english.hoshi.zst`](../../releases/latest/download/jmdict-english.hoshi.zst) — 27 MB |
| [JMnedict](https://www.edrdg.org/enamdict/enamdict_doc.html) | term (names) | 667,871 | [`jmnedict.hoshi.zst`](../../releases/latest/download/jmnedict.hoshi.zst) — 23 MB |
| [KANJIDIC2](https://www.edrdg.org/wiki/index.php/KANJIDIC_Project) | kanji | 10,384 | [`kanjidic2.hoshi.zst`](../../releases/latest/download/kanjidic2.hoshi.zst) — 0.7 MB |
| [Wiktionary JA→EN](https://github.com/yomidevs/kaikki-to-yomitan) | term | 692,524 | [`wiktionary-ja-en.hoshi.zst`](../../releases/latest/download/wiktionary-ja-en.hoshi.zst) — 35 MB |
| [Wiktionary IPA](https://github.com/yomidevs/kaikki-to-yomitan) | ipa | 56,477 | [`wiktionary-ja-en-ipa.hoshi.zst`](../../releases/latest/download/wiktionary-ja-en-ipa.hoshi.zst) — 1.7 MB |

Plus [`manifest.json`](../../releases/latest/download/manifest.json) and
[`SHA256SUMS`](../../releases/latest/download/SHA256SUMS).

```sh
curl -LO https://github.com/bee-san/hoshi-dictionaries/releases/latest/download/jitendex.hoshi.zst
zstd -d jitendex.hoshi.zst
hoshidicts-cli verify jitendex.hoshi
hoshidicts-cli query jitendex.hoshi 食べる
```

Any hoshidicts consumer takes a container where it takes a directory:

```cpp
DictionaryQuery query;
query.add_term_dict("jitendex.hoshi");
query.add_kanji_dict("kanjidic2.hoshi");
query.add_pitch_dict("wiktionary-ja-en-ipa.hoshi");
```

`manifest.json` lets a client poll for a new build and pick a loader without downloading
anything: it carries each dictionary's upstream tag, payload version, entry counts, and both
the compressed and uncompressed size and SHA-256.

**Gate on `payload_version`.** A payload v4 container carries a trained zstd dictionary and
needs an engine that knows about it; v3 does not. The large dictionaries here are v4;
KANJIDIC2 and the IPA dictionary are v3, because they are too small for the importer to train
on.

The download is not the win — `.hoshi.zst` is larger than the Yomitan zip it came from, and
decompressing expands it further. What you save is the import.

## Dictionaries this repository will not host

Most of the *recommended* Yomitan dictionaries cannot be redistributed. 大辞林, 大辞泉, 明鏡,
新明解, 三省堂, 広辞苑, 研究社 and DoJG are commercial products circulating as unauthorised
conversions. Pixiv Encyclopedia, Weblio, ニコニコ大百科 and the JPDB frequency list are site
scrapes with no redistribution grant. The popular frequency and pitch-accent dictionaries are
derived from licensed corpora or from NHK's accent dictionary.

Publishing those as release assets would be straightforward infringement, so this repository
does not. They are catalogued in [`dictionaries.json`](dictionaries.json) with the reason, and
you convert your own copy in one command:

```sh
scripts/pack.sh ~/Downloads/大辞林.zip
# -> 大辞林.hoshi
```

`pack.sh` takes any Yomitan dictionary zip, so it also works for anything not in the
catalogue.

## How it is built

`.github/workflows/build.yml` runs on the 15th of each month, so the dictionaries update
themselves. It is idempotent: it resolves every upstream release and does nothing if the
published `manifest.json` already records the same tags for all of them, which costs about
25 seconds. `workflow_dispatch` runs it by hand, with `force` to rebuild and republish anyway. `only`
builds a subset **without publishing** — a subset release would replace `latest` with one
missing the other dictionaries and break their stable URLs, so it is a smoke test, not a
partial update. To refresh one dictionary in the published set, use `force`. Want it fresher? `jmdict-yomitan` rebuilds daily, so changing the cron to
weekly is a one-line edit — the cost is a release per week rather than per month.

Each release also commits its `manifest.json` back to this repository, so
[`manifest.json`](manifest.json) always shows what is currently published without going near
the releases API. That commit is load-bearing for a second reason: GitHub
[disables cron on a public repository after 60 days with no repository activity](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule),
and publishing a release does not reset that clock. Without a commit per run the schedule
would quietly switch itself off after two months.

If a run fails — upstream renaming an asset is the likely cause — it files or comments on a
single tracking issue, because an unattended job that fails quietly is a job that has stopped
working.

Everything the workflow does lives in `scripts/build.sh`, so a broken run is reproducible:

```sh
git submodule update --init --recursive
cmake -S hoshidicts -B build -DCMAKE_BUILD_TYPE=Release -DHOSHIDICTS_CLI=ON
cmake --build build --target hoshidicts-cli --parallel
scripts/build.sh                       # all of them
ONLY=kanjidic2 scripts/build.sh        # just one
```

GCC 14 or newer is required — the engine is C++23 and uses `std::views::as_rvalue` and
`std::ranges::to`.

The build fails loudly if a packed container's payload version is outside
`ALLOWED_PAYLOAD_VERSIONS` (3 and 4), so a container format change becomes a deliberate,
reviewed commit here rather than an artifact nothing can read.

Adding a dictionary is one entry in `dictionaries.json` — `repo`, `release` (a tag or
`latest`) and `asset` — provided it is licensed for redistribution.

Byte-identical rebuilds are *not* achievable: the importer writes an `importDate` into
`index.json`, so two builds of the same upstream release differ. That is why checksums of what
was actually built are published rather than a reproducibility claim.

> The hoshidicts submodule is pinned to the branch that adds container support
> ([Manhhao/hoshidicts#31](https://github.com/Manhhao/hoshidicts/pull/31),
> [#32](https://github.com/Manhhao/hoshidicts/pull/32)). It moves to an upstream tag once
> those land.

Wiktionary is pinned to `v2025-04-08-10-54-36-00-00` rather than `latest`, because
kaikki-to-yomitan's newest release published its 889 index files without any of the
dictionary zips.

## License

Dictionary data is **CC BY-SA 4.0** and the containers inherit it. The workflow and scripts
here are **GPL-3.0-or-later**, matching hoshidicts. See [NOTICE.md](NOTICE.md) for the
attribution that redistribution requires.
