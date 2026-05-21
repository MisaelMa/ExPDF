# The MIT License (MIT)

Copyright (c) 2016 Andrew Timberlake (original `elixir-pdf` writer code)
Copyright (c) 2026 Misael Sánchez (PDF reader, error recovery, unified API)

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the “Software”), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## Bundled third-party data

### Spanish wordlists (`priv/wordlists/`)

#### `spanish.txt` — 50k base list

The 50,000-word Spanish frequency list at
`priv/wordlists/spanish.txt` is the `2018/es/es_50k.txt` file from
[`hermitdave/FrequencyWords`](https://github.com/hermitdave/FrequencyWords)
(MIT License, © Hermit Dave), with the per-line frequency column
removed so only the lowercase word survives. The frequencies are
themselves derived from the OpenSubtitles 2018 corpus.

#### `spanish_mx_extras.txt` — Mexican legal/fiscal vocabulary

Project-specific supplementary wordlist (~700 entries) curated for
Mexican tax-document extraction. Contains SAT terminology, common
labour/employment terms, document/process vocabulary, adverbs and
verb conjugations not present in the subtitle-derived 50k list.

Released under the project's MIT License.

```
The MIT License (MIT)

Copyright (c) 2016 Hermit Dave

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

### Adobe CMap resources (`priv/cmap/`)

The 40 predefined CMap files in `priv/cmap/` come from
[`adobe-type-tools/cmap-resources`](https://github.com/adobe-type-tools/cmap-resources)
(BSD-3-Clause).

### Adobe Glyph List (`priv/glyphlist.txt`) and CID maps (`priv/adobe-*.txt`)

Public-domain glyph-to-Unicode mappings sourced from Adobe.
