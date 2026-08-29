# Localization

**Status: English only, but built the native way.** Adding a language is adding a
column, no code.

## Where the copy lives

**`CouchToHour/Localizable.xcstrings`** — a String Catalog (Xcode 15+). It's a JSON
file you can edit by hand, and Xcode also gives it a dedicated editor (open the
file in Xcode: one row per string, one column per language, translation-state
flags, comments).

Keys are explicit dotted paths (`timer.endSession`, `today.dayTitle`). Call sites
never touch the catalog directly — they go through the typed `Copy.*` accessors
in `CouchToHour/Resources/Copy.swift`, which are thin `String(localized:)` calls.
The reason for the wrapper: the UIWorkouts components take plain `String`, not
`LocalizedStringKey`, so a call site has to resolve the string itself; centralising
that keeps the keys in one list and call sites readable.

**To revise copy:** edit the `value` for the `en` localization of a key in
`Localizable.xcstrings` (or use Xcode's editor). Nothing else changes.

Interpolated entries (`"Week %1$lld · Day %2$lld"`) carry a matching `defaultValue`
in `Copy.swift` — that English is a *fallback*; the catalog value wins at runtime.

## Adding a language

1. Open `Localizable.xcstrings` in Xcode → **+** language (or add the code to the
   project's known regions and a `"<lang>"` block per key in the JSON).
2. Fill the values — in Xcode, or export `.xcloc` (Product ▸ Export Localizations),
   hand it to a translator, import it back.
3. Nothing in Swift changes. The system picks the user's language at runtime and
   falls back to English.

## Why a String Catalog and not a hand-rolled JSON

Because reimplementing localization is a trap. The catalog gives us, for free:
the Xcode editor, automatic per-language `.lproj` compilation, plural / device
variants, `.xcloc` translator round-tripping, App Store Connect metadata tie-in,
stale-string detection, and a runtime (`String(localized:)`) that already handles
locale resolution, fallback, and format-arg positioning. A custom JSON loader
gets you the loader and nothing else.

## What's not covered

- `OnboardingCompletion.weekdaySymbols` (`["M","T","W",…]`) — layout-driving letters,
  left as-is; a real localization pass would derive them from `Calendar`.
- Number / date formatting is already locale-aware (`.formatted`, `WKTimeFormat`).
