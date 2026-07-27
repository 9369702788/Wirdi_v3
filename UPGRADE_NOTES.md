# Wirdi v1.1.0 — Production Upgrade Notes

This documents the audit/upgrade pass performed on top of the working
v1.0.0 codebase (Quran, Azkar, Tasbeeh, Prayer Times, Home, GitHub Actions
build — all already functional and building on a real device).

## What changed and why

### Architecture / code quality
- **Removed duplicated code**: `quran_screen.dart` had its own copy of the
  Quran-fetching/parsing logic (`QuranApi`, `SurahData`, `AyahData`)
  duplicating `QuranRepository`/`quran_models.dart`. Now there is exactly
  one Quran data path.
- **New `core/services/` layer**: `local_cache_service.dart`,
  `azkar_repository.dart`, `prayer_service.dart`, `settings_service.dart`,
  `user_progress_service.dart`. Screens no longer talk to `http`/
  `SharedPreferences` directly for anything that's shared state — they go
  through a repository/service, so Home Dashboard, Quran, Azkar, and
  Prayer Times all read the *same* persisted state instead of drifting.
- **New `core/models/`**: `azkar_models.dart`, `prayer_models.dart`.

### Offline-first
- `QuranRepository` and `AzkarRepository` now cache the last successful
  fetch (`SharedPreferences`) and serve it instantly on next launch while
  refreshing in the background. No cache + no network still surfaces a
  real, user-facing error with a retry button (never fake data).
- `PrayerService` caches the last successful AlAdhan response and falls
  back to it if location/network fails, with the UI clearly labeling the
  times as "آخر مواقيت محفوظة (بدون اتصال)" — never presented as live.

### Azkar — was hardcoded sample data, now real
- Replaced the 4-category hardcoded `Map` with `AzkarRepository`, pulling
  the full ~132-category Hisn Al Muslim dataset your app was already
  configured to point at (`AppSources.azkarJsonUrl`), offline-cached.
- Added: search (category + text), favorites (persisted), per-item
  counters that persist and **reset daily** (based on the actual date, not
  a fake timer), completion detection + haptic + snackbar, share-via-copy
  (no new dependency — uses Flutter's built-in `Clipboard`).

### Tasbeeh
- 6 selectable phrases instead of one fixed counter, each with its own
  persisted daily count + all-time total, progress ring toward a
  per-phrase target, daily reset that's actually date-based.

### Prayer Times
- Logic extracted into `PrayerService` so Home Dashboard's "next prayer"
  and the Prayer Times screen can never disagree.
- Real, distinct error states (`PrayerAvailability` enum): location
  service off, permission denied, denied forever, no network + no cache —
  each with its own message, instead of one generic string.

### Home Dashboard — was static placeholder text, now real
- Next prayer + live countdown: real, from `PrayerService`.
- Continue reading: real, from the last-saved reading position.
- Favorites count: real, summed across Quran ayahs + Azkar items.
- Daily wird progress: real. Added a "mark this surah as read today"
  action in the Quran reader that increments actual persisted progress
  against a target you set in Settings, plus a real streak counter.
- Quote of the day: a curated, deterministic-by-date rotation (not an
  external API call, not lorem-ipsum — real short ayat/hadith text).

### Settings (new module)
- Theme: light / dark / system, persisted, applies live (no restart).
- Font size slider, persisted, applies app-wide via `TextScaler`.
- Daily wird target stepper.
- About, Sources & Licenses (reuses your existing `AppSources` content,
  plus Flutter's built-in open-source license page), Privacy Policy
  (written to match exactly what this codebase does — see below), and a
  "delete all local data" action with a confirmation dialog.

### Play Store readiness
- In-app Privacy Policy page now exists and accurately describes: no
  accounts, location used only for prayer-time calculation and not
  stored/shared, all other data local-only, which three external data
  sources the app calls, no ads, no analytics.
- **You still need to**: host this policy text (or equivalent) at a public
  URL for the Play Console listing — I can't host a URL for you. Also
  still needed before submission: real app icon/screenshots, a completed
  Play Console Data Safety form (the privacy text above tells you exactly
  what to declare), and a human legal read-through if you're in a
  jurisdiction with extra requirements.

## Explicitly NOT done in this pass (and why)

- **Full offline audio recitation library**: this is gigabytes of
  licensed audio files. Bundling "the entire Quran, offline, all
  reciters" isn't something that fits in an app download either
  technically or in terms of what I can source/verify here. The
  architecture (repository pattern, offline cache) is ready for a
  streaming-with-download-for-offline audio feature as a follow-up.
- **Riverpod / clean-architecture DI / sqflite or Isar for local
  storage**: you asked me not to risk breaking the Android build with new
  dependencies, and I can't compile-test locally in this sandbox. Current
  code stays on `SharedPreferences` + a repository pattern, which is a
  real, working offline-first design — just not a full DB-backed one.
- **Formal accessibility audit / performance profiling**: needs a running
  device/DevTools session, which I don't have here.
- **Qibla compass**: still out of scope per your own v1.0 brief (deferred
  to v1.1 in your original spec, and needs real-device compass testing).

## Before you rely on this build

I could not run `flutter analyze` / `flutter build` locally (no Flutter
SDK reachable from this sandbox — see the GitHub Actions workflow notes
in the main README). I reviewed every changed file manually (imports,
brace/paren balance, consistent method signatures across the new service
layer), but the real verification is your CI run. If it fails, paste me
the exact log and I'll fix it — I'd rather see the real compiler error
than guess.
