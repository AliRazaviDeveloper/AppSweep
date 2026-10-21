## Install

**One-line install (recommended)** — paste into Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/AliRazaviDeveloper/AppSweep/main/install.sh | bash
```

**Or download [AppSweep.dmg](https://github.com/AliRazaviDeveloper/AppSweep/releases/latest/download/AppSweep.dmg)** — universal build for Apple Silicon & Intel, macOS 14 or later.
Drag **AppSweep** into **Applications**, then run once:

```bash
xattr -dr com.apple.quarantine /Applications/AppSweep.app
```

> AppSweep isn't notarized by Apple yet, so a browser-downloaded copy shows *"Apple could not verify…"* with a **Move to Trash** button. The command above (or **System Settings → Privacy & Security → Open Anyway**) lets it open. The one-line installer avoids the prompt entirely.

## What's inside

- **Complete uninstaller** — removes an app together with its caches, preferences, containers, logs, saved state, cookies and launch agents.
- **Cache Cleaner** — app caches, logs and developer junk (Xcode DerivedData, simulator caches, npm, Gradle…).
- **Leftovers finder** — data left behind by apps you've already deleted.
- **Overview dashboard** — disk usage at a glance and your largest apps.
- **Safe by default** — everything goes to the Trash and can be restored.
- **English & Persian** — full right-to-left layout for فارسی.

See [CHANGELOG.md](https://github.com/AliRazaviDeveloper/AppSweep/blob/main/CHANGELOG.md) for details.
