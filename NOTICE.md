# Notice

Every container published by this repository is a **format conversion**: the files a
hoshidicts import produces are copied byte for byte into a single file. No entries are added,
removed or edited.

All of it is **CC BY-SA 4.0**, so the containers are CC BY-SA 4.0 too. Redistributing them,
or anything derived from them, requires the same attribution and the same license.

## Dictionary data

- **Jitendex** — © Stephen Kraus and contributors, <https://jitendex.org>,
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Built from JMdict, with
  example sentences from [Tatoeba](https://tatoeba.org/).
- **JMdict**, **JMnedict**, **KANJIDIC2** — © the
  [Electronic Dictionary Research and Development Group](https://www.edrdg.org/), used under
  the [EDRDG licence](https://www.edrdg.org/edrdg/licence.html), which is CC BY-SA 4.0.
  Converted to Yomitan format by [yomidevs/jmdict-yomitan](https://github.com/yomidevs/jmdict-yomitan).
- **Wiktionary** — © Wiktionary contributors,
  [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Extracted by
  [Tatuylonen's wiktextract](https://github.com/tatuylonen/wiktextract) and converted to
  Yomitan format by [yomidevs/kaikki-to-yomitan](https://github.com/yomidevs/kaikki-to-yomitan).

## What is deliberately not here

Many widely recommended Yomitan dictionaries carry no redistribution grant — commercial
monolinguals circulating as unauthorised conversions, and site scrapes such as Pixiv
Encyclopedia and Weblio. They are listed in [`dictionaries.json`](dictionaries.json) under
`byo` with the reason, and `scripts/pack.sh` converts a copy you already have. Nothing about
them is hosted here, and no download link for them will be added.

## Build tooling

- **hoshidicts** — <https://github.com/Manhhao/hoshidicts>, GPL-3.0-or-later. Vendored as a
  submodule and used to import and pack. Its license governs the tool, not the dictionary
  data it processes.
- The workflow and scripts in this repository are GPL-3.0-or-later, matching hoshidicts.
