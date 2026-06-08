# Changelog

All notable changes to Prayer Times are documented here. This project adheres to
[Semantic Versioning](https://semver.org) and the
[Keep a Changelog](https://keepachangelog.com) format.

## [0.5.1] - 2026-06-08

### Fixed
- **Bengali menu bar countdown was ambiguous.** "Next prayer in X" and the new "time left in the current prayer" countdown both rendered with the same Bengali word (বাকি), so the two modes were indistinguishable. The upcoming countdown now reads with পর ("in"), distinct from বাকি ("left") for the current prayer.

## [0.5.0] - 2026-06-08

### Added
- **Today's Hijri (Islamic) date in the panel.** Shown beneath the Gregorian date, using the calculated Umm al-Qura calendar. Because the Islamic date can differ by country — Saudi Arabia and Bangladesh often observe Eid on different days — a **−2…+2 day adjustment** (Location & Time settings) lets you align it to your country's local moon-sighting. Localized month names and era in Arabic, Bengali, and Turkish.
- **"Time left in the current prayer" menu bar countdown.** A new option lets the menu bar count down to the *end* of the current prayer's window (e.g. "Asr 40m left") instead of the time until the next prayer — so you can see at a glance how long you still have to pray. Switch between the two in General settings.
- **Optional Ishraq time in the panel.** Enable "Show Ishraq time" to display when the voluntary Ishraq/Duha prayer becomes valid, listed right after Sunrise.

## [0.4.0] - 2026-06-06

### Added
- **JAKIM (Malaysia) calculation method.** Calibrated against JAKIM's official e-Solat tables so prayer times match what Malaysian users see in the official service — not the generic "Fajr 20°/Isha 18°" preset other apps mislabel as JAKIM, which runs Fajr about 11 minutes early. Auto-detect now selects JAKIM in Malaysia.
- **Kemenag (Indonesia) calculation method.** Calibrated against the official Kementerian Agama (Kemenag) tables, including the standard Indonesian *ihtiyati* safety minutes, so times match Kemenag's published schedule. Auto-detect now selects Kemenag in Indonesia.

### Fixed
- **Prayer times displayed up to a minute early.** Times were truncated to the minute instead of rounded, so a calculated 1:14:53 showed as "1:14" rather than "1:15". They are now rounded to the nearest minute — matching official prayer tables — across every calculation method, and the clock, notifications, and countdown all stay on the same minute.

## [0.3.1] - 2026-06-05

### Fixed
- **Missing Fajr and wrong Isha at high latitudes.** In northern locations (e.g. Kraków, Poland) the sun never reaches the required twilight depression angle in summer, so Fajr disappeared and Isha showed up near midnight. The app was discarding each calculation method's recommended high-latitude rule; it now honors it by default (e.g. Muslim World League's angle-based rule), so Fajr and Isha are computed sensibly and match the standard references.
- **New users got Istanbul prayer times.** A first-time install defaulted to a hardcoded manual Istanbul location, so someone opening the app in, say, Dhaka saw Istanbul times. First launch is now location-aware: it follows your system timezone immediately and asks to detect your location.
- **Switching from Automatic to Manual location lost your detected place.** Flipping to Manual snapped back to the old stored coordinates instead of keeping the location that was just detected. The detected coordinates now carry over.

### Changed
- **Menu bar now shows the icon, next prayer name, and countdown by default**, with the countdown written as "Asr in 4h 21m" / "in 21m" instead of the ambiguous "Asr 1:24". Fully localized (Arabic, Bengali, Turkish).
- **The menu bar mosque glyph is centered** and aligned with neighbouring menu bar icons.

## [0.3.0] - 2026-06-03

### Fixed
- **Wrong prayer times after auto-detecting location.** Detecting your location
  updated the coordinates but left the master timezone pointing elsewhere, so the
  times were computed for one place and shown on another's clock (e.g. Dhaka
  coordinates with an Istanbul timezone). Auto-detect now locks the timezone to
  the detected location, and the coordinates shown in Automatic mode are the ones
  actually in use.
- **Notifications not firing.** On a fresh install, notifications were scheduled
  before macOS granted permission and were never re-registered afterward. They are
  now rescheduled once permission resolves. Combined with the timezone fix above
  (which had pushed many alerts into the past), prayer notifications now fire at
  the correct local times.
- **"Detect my location" could hang** if tapped repeatedly or while a detection
  was already running; concurrent requests are now coalesced.
- **Adhan no longer replays on wake from sleep** for a prayer time that already
  passed while the Mac was asleep.
- **Settings are no longer reset on upgrade.** App settings now decode resiliently,
  so a future field addition can't wipe your configuration back to defaults.

### Added
- **In-app notification hint.** The Notifications settings tab now warns when macOS
  is blocking notifications, with a button to open System Settings — and prompts you
  to send a sample notification when permission hasn't been requested yet.
- **Timezone mismatch warning** in Location & Time when the timezone and detected
  location describe different places.
- All new strings are fully localized in Arabic, Bengali, and Turkish.

### Changed
- The Homebrew cask is now maintained solely in the
  [tap repo](https://github.com/tareq1988/homebrew-tap); the redundant in-repo copy
  was removed.

## [0.2.1] - 2026-06-02
- Fixed a launch crash in ad-hoc builds caused by hardened-runtime library
  validation rejecting the Sparkle framework.

## [0.2.0] - 2026-06-02
- Green app branding and menu bar glyph, "send a sample notification" button, README.

## [0.1.0] - 2026-06-02
- First public release: menu bar prayer times, configurable notifications, Adhan
  playback, pluggable calculation methods, Sparkle auto-update, and Homebrew cask.
