<p align="center">
  <img src="Shelfie/Resources/Assets.xcassets/BrandMark.imageset/BrandMark.png" width="96" alt="Shelfie icon">
</p>

<h1 align="center">Shelfie — An expiry tracker for your kitchen</h1>

<p align="center">
  Keep fridge, freezer, and pantry food from going to waste.<br>
  No account. No ads. No tracking. Everything stays on your device.
</p>

<p align="center">
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-5.10-orange?logo=swift&logoColor=white" alt="Swift 5.10">
  </a>
  <a href="https://www.apple.com/ios">
    <img src="https://img.shields.io/badge/iOS-17%2B-blue?logo=apple&logoColor=white" alt="iOS 17+">
  </a>
  <a href="https://github.com/xiaotwu/food-shelfie/actions/workflows/ci.yml">
    <img src="https://github.com/xiaotwu/food-shelfie/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="MIT License">
  </a>
  <a href="https://github.com/xiaotwu/food-shelfie">
    <img src="https://img.shields.io/github/stars/xiaotwu/food-shelfie?style=social" alt="GitHub stars">
  </a>
</p>

Shelfie is a native iOS app for tracking what you have on the shelf and when it expires. Scan a barcode or an expiry date, organize by location or category, and get reminded before food goes bad — without sending your inventory to a cloud account.

<div align="center">

| Shelf | Insights | About |
|:---:|:---:|:---:|
| <img src="Screenshots/shelf.jpg" width="270" alt="Shelf view"> | <img src="Screenshots/insights.jpg" width="270" alt="Insights view"> | <img src="Screenshots/about.jpg" width="270" alt="About view"> |

</div>

## Key Capabilities

- **Private by default** — Inventory, photos, and settings live on device. Face ID / passcode lock is optional. The only network call is a barcode lookup against [Open Food Facts](https://world.openfoodfacts.org).
- **Scan, don't type** — Live barcode scanning fills in name, brand, photo, and category. Apple Vision OCR reads expiry and production dates from the camera or an existing photo.
- **Freshness at a glance** — Color-coded rings and countdowns for fresh, warning (4–7 days), urgent (≤3 days), and expired. Long-press to batch-mark items as eaten or discarded.
- **Kitchen, not a spreadsheet** — Fridge, freezer, pantry, plus custom locations and categories. Sort by expiry, name, or recency; search by name, owner, location, or category.
- **Insights that change habits** — Expired vs expiring-this-week counts, a freshness mix, eaten-vs-discarded trends, and an anti-waste rate over 7 or 30 days.
- **Reminders and widgets** — Daily expiry alerts, an optional weekly summary, and Home Screen widgets for this week's expiring items.
- **Yours to keep** — JSON backup export/import (including photos), optional iCloud sync, English (US) and Simplified Chinese with an in-app language picker.

## Features

| Area | What it does |
|:---|:---|
| **Shelf** | Filter by storage location or category; urgent-item chip; empty state that jumps to add/scan |
| **Cards** | Photo, location pill, freshness ring, remaining-days badge, category and owner |
| **Add / edit** | Name, photo, owner, notes, purchase date, expiry date, location, category — plus +3d / +7d / +2w / +1m presets |
| **Scanning** | Barcode → Open Food Facts; date OCR from camera or Photo Library; torch; first-run camera policy |
| **Search** | Local history; scopes for all / name / owner / location / category |
| **Resolve** | Mark eaten or discarded one-by-one or in bulk; optional auto-delete of consumed items after 0–90 days |
| **Insights** | Hero counts, efficiency banner, weekly expiry bars, freshness donut, eaten vs discarded chart |
| **Reminders** | Daily notification at a chosen time; warning window 0–14 days; optional Sunday weekly report |
| **Appearance** | System / light / dark; five seed colors (sapphire, ruby, topaz, emerald, amethyst) |
| **Lock & data** | Face ID lock; iCloud CloudKit toggle; JSON backup; delete-all with category/location restore |
| **Widgets** | *Expiring* (small + medium) lists items due this week; *This week* (medium) shows daily bars plus expired / soon counts |
| **Languages** | English (US) and Simplified Chinese; in-app picker independent of system locale |

## Quick Start

```bash
git clone https://github.com/xiaotwu/food-shelfie.git
cd food-shelfie
brew install xcodegen   # if needed
xcodegen generate
open Shelfie.xcodeproj
```

Select the **Shelfie** scheme, choose your development team, and run on a simulator or device.

> **Note:** If command-line `xcodebuild` fails with a CoreSimulator / asset-catalog runtime mismatch, open the project in Xcode and run from there. That error comes from the Mac's simulator runtime, not from Shelfie.

The app and the widget extension share data through the App Group `group.com.xiaotwu.shelfie`. Enable that App Group on both targets when building for a physical device. Optional iCloud sync uses the CloudKit container `iCloud.com.xiaotwu.shelfie`.

## Requirements

- iOS 17 or later (iPhone and iPad)
- Xcode 16 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate `Shelfie.xcodeproj`
- Optional permissions: Camera (scan), Photo Library (photos + OCR), Face ID (lock), Notifications (reminders)

## Privacy

Inventory, photos, search history, and settings stay on the device by default. Camera access is used only for barcode scanning and expiry-date OCR. Product lookups go to Open Food Facts when you scan a barcode; nothing else is transmitted. There is no account, analytics SDK, or advertising.

## Architecture

| Layer | Technology |
|:---|:---|
| UI | SwiftUI, Swift Charts |
| Data | SwiftData, App Groups, optional CloudKit |
| Vision | Apple Vision (barcode + text recognition) |
| Notifications | UserNotifications |
| Widgets | WidgetKit |
| Product data | Open Food Facts |

```
Shelfie/
├── Shelfie/                 # App target
│   ├── App/                 # Entry point and floating tab island
│   ├── Features/            # Inventory, scanner, entry, analytics, settings, lock, search
│   ├── Data/                # Backup, images, Open Food Facts, settings, widget snapshots
│   ├── Services/            # Biometrics, category mapping, notification scheduling
│   ├── Design/              # Theme and motion tokens
│   └── Resources/           # Assets and Info.plist
├── ShelfieWidgets/          # Home Screen widgets
├── Shared/                  # Models, freshness rules, localization (app + widgets)
├── ShelfieTests/            # Freshness, validation, and date-parser unit tests
├── ci_scripts/              # Xcode Cloud post-clone hook
├── .github/workflows/       # GitHub Actions CI and release
└── project.yml              # XcodeGen project definition
```

## Localization

All strings live in `Shared/Localizable.xcstrings`. The app resolves translations through an explicit language bundle (`L10n.swift`), so the in-app language setting works even when the system locale differs.

To add a language:

1. Add the locale to `knownRegions` in `project.yml`
2. Add translations to `Localizable.xcstrings`
3. Add the locale resolution to `L10n.resolved(_:)`

## Continuous Integration

### GitHub Actions

- **[`.github/workflows/ci.yml`](.github/workflows/ci.yml)** — generates the Xcode project, builds unsigned for the iOS Simulator, and runs unit tests on every push/PR to `main`
- **[`.github/workflows/release.yml`](.github/workflows/release.yml)** — archives an unsigned build and publishes a GitHub Release when you push a tag like `v1.1`

```bash
git tag -a v1.1 -m "Release v1.1"
git push origin v1.1
```

The release asset is unsigned. To run it on a device, re-sign with your own certificate.

### Xcode Cloud

`ci_scripts/ci_post_clone.sh` runs `xcodegen generate` before the cloud build starts. To connect:

1. In Xcode, open **Product > Xcode Cloud > Create Workflow**
2. Pick the **Shelfie** scheme
3. Link this GitHub repository when prompted
4. The default **Archive** action will build, sign, and upload to App Store Connect

The first archive may fail if App Groups or the iCloud container are not available for App Store provisioning. Xcode Cloud will usually prompt you to fix this in **Signing & Capabilities**.

## Support

- **Bug reports and ideas:** [GitHub Issues](https://github.com/xiaotwu/food-shelfie/issues)

## Contributing

Issues and pull requests are welcome. For larger changes, open an issue first so we can agree on the approach.

## License

Shelfie is available under the [MIT License](LICENSE).
