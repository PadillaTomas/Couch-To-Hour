# Localization

**Status: not localized.** The app ships English only. This doc explains what we
have, how iOS localization normally works, and the path to real i18n if it's ever
scoped.

## What we have today

All product copy is in **`CouchToHour/Resources/Copy.en.json`**, read through the
typed `Copy.*` accessors in `CouchToHour/Resources/Copy.swift`.

```
Copy.Timer.endSession                     // "End session"
Copy.Today.dayTitle(week: 2, day: 1)      // "Week 2 · Day 1"   ({week}/{day} filled from args)
Copy.Onboarding.weekBlurbs                // [String] (6 entries)
```

The loader already looks for **`Copy.<languageCode>.json`** first and falls back
to `Copy.en.json`. So a second language is, mechanically, just a new file:

```
CouchToHour/Resources/
  Copy.en.json      ← the source of truth
  Copy.es.json      ← drop this in and Spanish devices use it. No code change.
  Copy.fr.json
```

`languageCode` comes from `Locale.current.language.languageCode` — `"es"`, `"fr"`,
`"pt"`, … (not region; `pt-BR` and `pt-PT` would both look for `Copy.pt.json`).

### Why a JSON file instead of the native mechanism

- One obvious file, editable by anyone without opening Xcode.
- Trivial to diff and review in a PR (which is the whole point of CTH-10).
- No build-time string extraction to reason about.

### What we give up by not using the native mechanism

- Xcode's String Catalog editor (translation status, "stale" flags, comments).
- Automatic plural / count handling (`"%lld days"` → language-correct plural forms).
- `xcloc` export/import — the standard hand-off format for translation vendors.
- App Store Connect localized metadata tie-in.
- `Text("literal")` auto-localizing itself — with our approach every string must
  go through `Copy.*` explicitly.

None of that matters at one language. All of it matters at ~5+.

## How iOS localization normally works

Modern iOS (Xcode 15+) uses a **String Catalog**: a single
`Localizable.xcstrings` file (JSON under the hood) with a column per language.

- `Text("Start session")` or `String(localized: "Start session")` — the literal
  is both the *key* and the English value.
- At build time Xcode extracts every such literal into the catalog.
- Translators fill the other languages (in Xcode, or via exported `.xcloc`).
- At runtime the system picks the row matching the user's preferred languages,
  falling back to the development language (English).
- Per-language `.lproj` folders are produced automatically inside the app bundle.
- Plurals/device variants are first-class (no separate `.stringsdict`).

The older mechanism — `Localizable.strings` (`"key" = "value";`) plus
`Localizable.stringsdict` for plurals, one pair per `xx.lproj` — still works and
is what String Catalogs compile down to.

## Migration path (only if we commit to shipping multiple languages)

The typed `Copy.*` layer is the seam that makes this cheap — **call sites never
change**, only the backing store does.

1. Add `Localizable.xcstrings` to the target.
2. Script `Copy.en.json` → `xcstrings` entries (key = dotted path, value = string;
   `{placeholder}` → `%@` / positional args).
3. Repoint `Copy.string(_:_:)` from the JSON dictionary to
   `String(localized: LocalizationValue(key))` (or `Bundle.localizedString`).
4. Delete `Copy.*.json` and the JSON loader; keep `Copy.swift`'s accessors.
5. Hand `.xcloc` exports to translators; import back.

Until then: keep editing `Copy.en.json`.
