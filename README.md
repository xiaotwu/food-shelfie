# Shelfie

[![Swift](https://img.shields.io/badge/Swift-5.10-orange?logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17%2B-blue?logo=apple&logoColor=white)](https://www.apple.com/ios)
[![Xcode](https://img.shields.io/badge/Xcode-16%2B-147EFB?logo=xcode&logoColor=white)](https://developer.apple.com/xcode)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Shelfie is a native iOS app that tracks food expiration dates and helps you waste less. Store groceries by shelf (fridge, freezer, pantry, other), scan barcodes for instant product info, and get reminded before anything spoils.

Shelfie is a SwiftUI remake of the Android app [Algidy](https://github.com/NhuHuy-79/Algidy).

## Screenshots

> Coming soon.

## Features

- **Shelf organization** — sort items by storage location or custom category
- **Barcode scanning** — camera lookup on [Open Food Facts](https://world.openfoodfacts.org/)
- **Expiry-date OCR** — read dates from a photo or your library using Apple Vision
- **Manual entry** — name, photo, purchase/expiry dates, notes, custom categories
- **Search** — with local history and instant filters
- **Batch resolve** — mark items eaten or discarded, individually or in bulk
- **Analytics** — expired vs expiring counts, weekly bars, freshness mix, eaten vs discarded
- **Reminders** — daily expiry alerts and an optional weekly summary
- **Privacy lock** — Face ID or passcode
- **Backup** — export/import JSON, or clear everything
- **Localization** — English (US) and Simplified Chinese, with an in-app language picker
- **Home-screen widgets** — this week's expiring items and weekly counts at a glance

## Requirements

- iOS 17 or later
- Xcode 16 or later
- Optional permissions: Camera (scan), Photo Library (OCR), Face ID (lock), Notifications (reminders)

## Build

```bash
git clone git@github.com:xiaotwu/food-shelfie.git
cd food-shelfie
xcodegen generate
open Shelfie.xcodeproj
```

Select the **Shelfie** scheme, choose your development team, and run on a simulator or device.

If command-line `xcodebuild` fails with a CoreSimulator / asset catalog runtime mismatch, open the project in Xcode and run from there. That error is from the Mac's simulator runtime, not from Shelfie's sources.

The app and the widget extension share data through the App Group `group.com.xiaotwu.shelfie`. Enable that App Group on both targets when building for a physical device.

## Design

- **Liquid Glass** — Apple's latest material language applied to cards, controls, and the custom tab island
- **Pure icons** — the bottom tab island shows only symbols; text remains available via VoiceOver
- **Accent theming** — five seed colors drive the tint across every screen

## Architecture

| Layer | Technology |
|---|---|
| UI | SwiftUI, Swift Charts |
| Data | SwiftData, App Groups |
| Vision | Apple Vision (barcode + OCR) |
| Notifications | UserNotifications |
| Widgets | WidgetKit |
| Product data | Open Food Facts |

## Localization

All strings are in `Shared/Localizable.xcstrings`. The app resolves translations through an explicit language bundle (`L10n.swift`), so the in-app language setting works even when the system locale differs.

To add a language:

1. Add the locale to `knownRegions` in `project.yml`
2. Add translations to `Localizable.xcstrings`
3. Add the locale resolution to `L10n.resolved(_:)`

## Project structure

```
Shelfie/
├── Shelfie/            # App targets
│   ├── App/            # Entry point and root
│   ├── Features/       # Inventory, scanner, entry, analytics, settings, lock, search
│   ├── Data/           # Store, backup, image, and network layers
│   ├── Design/         # Theme and motion tokens
│   └── Resources/      # Assets and info property lists
├── ShelfieWidgets/     # Home-screen widgets
├── Shared/             # Business logic and localization shared by app + widgets
│   ├── Localizable.xcstrings
│   └── L10n.swift
└── project.yml         # XcodeGen project definition
```

## Privacy

Inventory, photos, and settings never leave the device by default. Camera access is used only for barcode scanning and OCR. Product lookups go to Open Food Facts; nothing else is transmitted.

## Contributing

Issues and pull requests are welcome. For major changes, open an issue first to discuss what you would like to change.

## License

Shelfie is available under the [MIT License](LICENSE).
