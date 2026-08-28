# Couch to Hour

An iOS app with a single fixed **6-week interval running plan** that takes a beginner
from short walk/run intervals to a sustained 50-minute continuous run.

The plan is built around **time held running, not distance**. No kilometres, no pace,
no GPS. Run at a pace where you can still hold a conversation — no rush, no race.

## Principles

- **Time, not distance** — the app only ever shows duration held running.
- **Local-first** — no login, no backend, no account. All data stays on device (SwiftData).
- **One-time purchase** — no subscription.
- **Fixed plan** — the 6-week plan is hardcoded and non-editable; its taper/peak/recover
  sequencing is the point.
- **No pressure** — calm onboarding, flexible scheduling, no guilt on missed days.

## MVP Step 1 scope

- Hardcoded 6-week plan
- Onboarding: 3-Day Plan vs Free Run, philosophy screen, starting-week picker
- Per-session interval list
- Timer screen with simple tone cues (3-2-1 countdown + interval-change tone)
- Mark Done (manual + automatic on timer completion)
- Missed-day handling: prompt on next open, user decides
- Calendar view of completed sessions
- Post-workout effort rating (1–10)
- Light + dark theme

### Explicitly out of scope

GPS / distance tracking, Apple Watch app, spoken/voice coaching, multiple plan templates.

## Tech

- Swift / SwiftUI
- SwiftData for local persistence
- Target: iOS

## Repository workflow

- `main` — stable, tagged releases
- `develop` — active development branch
- feature branches off `develop`

## Project docs

Requirements, research, and business notes live in Confluence:
[Couch to Hour — Home](https://padillatomas.atlassian.net/wiki/spaces/~6197f3bd3618cd006f47649b/pages/4358165/Couch+to+Hour+-+Home)

Issue tracking: [CTH board](https://padillatomas.atlassian.net/jira/software/projects/CTH/boards/35)
