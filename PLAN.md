# Mossling · 苔生 — native Android app

The web handbook (`app/`, WebView) is now source material only. `native/` is a new Android app, built from scratch:
Kotlin, Jetpack Compose, Material 3. The goal is a mature, award-calibre app (Google Play "Editors' Choice" bar):
fast and fluid first, then interaction, then information design. Nothing in it should feel like a web page.

## Product
- **Name**: Mossling · 苔生. Moss grows slowly and steadily: the app follows the child (Montessori), it does not push.
- **Characters**: **Moss** (two eyes; a soft mossy boulder with a sprout; it watches) and **Otto** (one big eye under a
  heavy lid; tall, a little lopsided; it concentrates; carries a golden bead). Deadpan European picture-book
  characters: flat matte shapes, no outlines, expression in the eyes, never mainstream-cute, no anime, no Chinese motifs.
  Geometry lives in `app/src/main/java/app/mossling/ui/ip/Creatures.kt` (100×100 box).
- **Palette** (Montessori materials): moss green, rod blue, golden bead, natural wood, chalk paper, ink.
- **Voice**: calm, short, factual. No nagging, no repeated disclaimers. All sources, method notes and legal text live
  in one place (You › About & sources) and nowhere else.
- **Data semantics** (must hold everywhere): observed (观察) / did an activity (做过) / health record (接种儿保, only ever
  ticked one by one) are separate; an activity done never implies a skill reached.

## Information architecture
- **Today**: age in big numerals with the character; one play for today (swipe for another, skip for today);
  continue (running timer or last reading); quick log; next health item, quietly.
- **Grow**: the 0–36 month **golden bead chain** scrubber (haptic tick per month) above the month: highlights,
  six areas, plays, things to notice, health items. Plays open full screen, step by step.
- **Journal**: day timeline, quick log, timers as a foreground service with an ongoing notification; week strip.
- **You**: this month's record by kind, keepsakes, settings (birth date, character, theme), About & sources.

## Engineering rules
- Single-activity Compose app, Navigation Compose (type-safe routes), MVVM with StateFlow, Room for records, DataStore
  for settings, content from `assets/content.json` (exported from the web sources by `tools/export_content.py`).
- Smoothness budget: no work on the main thread at startup beyond the first frame; lists are lazy; characters are drawn
  with cached Paths; animations use `graphicsLayer`; baseline profile before 1.0.
- Every change must build on CI (`.github/workflows/native.yml`) and produce Paparazzi screenshots of every screen
  (light/dark, Moss/Otto). Look at the screenshots before calling anything done.
- Separate applicationId (`app.mossling`) until the switch-over; the WebView app stays untouched meanwhile.

## Plan (tick items as they are done; the scheduled runs take the first unticked item)
### Phase 1 — foundation
- [x] Content bundle exported to `app/src/main/assets/content.json` (37 months, 46 plays, sources in one list)
- [x] Character design v1 (Moss, Otto; moods open/happy/wow/sleep; look direction; lid)
- [ ] Gradle project, theme (colour roles light/dark, type scale, shapes), app icon (adaptive + monochrome)
- [ ] Content repository + age calculation + settings (DataStore) + records (Room)
- [ ] Navigation shell: four destinations with character tab icons, edge-to-edge, predictive back
- [ ] Today screen
- [ ] Grow screen with the bead chain scrubber
- [ ] Month detail sections; Play detail (step pager, safety first, "did this" with undo)
- [ ] Journal: quick log, timeline, timers (foreground service + notification), edit/retro-fill
- [ ] You: record by kind, settings, About & sources (single place)
- [ ] Onboarding: birth date in one screen, skippable
- [ ] Paparazzi screenshots for all screens in CI; artifact + preview release `mossling-preview`
### Phase 2 — craft
- [ ] Motion pass: shared element Today→Play, bead chain physics, character idle (blink, glance), reduced motion
- [ ] Character expressions tied to context (sleep at night, focus on timers, glance toward the chain)
- [ ] Illustrations: the web cut-paper scenes rasterised to WebP per play step; consistent frame and grain
- [ ] Glance widgets: age + last feed + quick log; timer live in widget
- [ ] Notifications: health items (opt-in, quiet), timer ongoing; no other reminders
- [ ] Typography pass: CJK sizes, line heights, numerals in Young Serif; large-font layouts
- [ ] Accessibility: TalkBack labels, 48dp targets, contrast in both themes
### Phase 3 — maturity
- [ ] Import from the WebView app (one-time migration of ticks, journal, birth date)
- [ ] Baseline profile + macrobenchmark (startup, scroll, chain scrub)
- [ ] Emulator UI tests (critical paths) in CI
- [ ] Store listing assets (screenshots, feature graphic), privacy statement
- [ ] Switch-over plan: same applicationId as the WebView app, signed with the same key, data migrated
