# Changelog

All notable changes to AppSweep are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] — 2026-10-21

### Added
- Complete uninstaller that detects an app's related files across `~/Library` and `/Library`
  (Application Support, Caches, Preferences, Containers, Group Containers, Logs, Saved State,
  HTTP storage, WebKit data, Cookies, Launch Agents/Daemons and privileged helpers).
- App reset: remove an app's data while keeping the app installed.
- Cache Cleaner for app caches, logs and developer junk (Xcode DerivedData, Device Support,
  simulator caches, npm, Gradle, pnpm).
- Leftovers finder for data belonging to apps that are no longer installed.
- Overview dashboard with disk usage, totals and largest apps.
- Drag & drop any `.app` onto the window to inspect it.
- Safe removal: items are moved to the Trash, running apps are quit first and protected system apps can't be removed.
- English and Persian localization with right-to-left layout.
- Universal binary for Apple Silicon and Intel.

[1.0.0]: https://github.com/AliRazaviDeveloper/AppSweep/releases/tag/v1.0.0
