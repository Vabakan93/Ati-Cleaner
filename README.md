# Ati Cleaner

Ati Cleaner is a native macOS cleaning and storage-inspection utility built with SwiftUI and Swift Package Manager. The project is designed around a simple rule: **scan broadly, delete conservatively**.

## Goals

Ati Cleaner focuses on real-world Mac maintenance workflows without pretending that every cache or large file is automatically safe to remove. Scanning and deletion are separated, destructive actions require explicit user intent, and permanent deletion is opt-in.

### Included modules

- **Overview** — disk, memory and quick health summary
- **System Junk** — user caches, logs and temporary files in known-safe locations
- **Large Files** — configurable size threshold and scan location
- **Duplicates** — content-based duplicate detection using SHA-256
- **Trash** — local Trash plus optional external-volume trash discovery
- **Uninstaller** — lists installed applications and moves selected apps to Trash
- **Memory** — live memory snapshot and pressure-oriented summary

## Architecture

```text
Ati-Cleaner/
├── Sources/
│   ├── AtiCleanerApp/      # SwiftUI UI + view models
│   └── AtiCleanerCore/     # scanners, policies, models, system services
├── Tests/
├── Scripts/
├── Assets/
└── .github/workflows/
```

The app uses a fixed-width custom sidebar rather than `NavigationSplitView`. This keeps navigation visually stable and avoids macOS sidebar collapse/reflow behavior during state changes.

## Safety model

Ati Cleaner intentionally avoids “one-click delete everything” behavior.

- Default deletion uses Finder Trash semantics.
- Permanent deletion is disabled by default and must be explicitly enabled.
- System roots such as `/System`, `/usr`, `/bin`, `/sbin` and protected Library locations are excluded by policy.
- Duplicate files are matched by content hash, not filename alone.
- The first file in each duplicate group is preserved by default.
- App uninstall does not blindly remove support files from `~/Library`; that can be added later as a reviewed, per-app workflow.
- Permission failures are surfaced instead of being silently interpreted as “0 files found”.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools / Swift 6 compatible toolchain
- Full Disk Access is recommended for complete Trash and Library scanning

## Build from source

```bash
swift build
```

Run the debug executable:

```bash
.build/debug/AtiCleaner
```

Build a distributable `.app` bundle:

```bash
./Scripts/build-app.sh
```

The resulting app is created at:

```text
dist/Ati Cleaner.app
```

Create a DMG after building the app:

```bash
./Scripts/make-dmg.sh
```

## Code signing

`Scripts/build-app.sh` supports an optional signing identity through an environment variable:

```bash
ATI_CODESIGN_IDENTITY="Developer ID Application: Your Name (...)" ./Scripts/build-app.sh
```

If no identity is supplied, the script falls back to ad-hoc signing for local testing.

## GitHub Actions

The macOS CI workflow runs `swift test` and `swift build -c release` on pushes and pull requests.

## Roadmap

Planned improvements include scan-history persistence, richer per-category disk analytics, reviewed application leftovers, external-volume dashboards, notarization automation and localization.

## Privacy

Ati Cleaner is designed to operate locally. File names, paths and scan results should not leave the Mac unless a future feature explicitly states otherwise. Production logging should avoid recording personal filenames by default.
