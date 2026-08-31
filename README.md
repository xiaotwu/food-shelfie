# Shelfie

Shelfie is an iOS food expiry tracker. It is a SwiftUI remake of [Algidy](https://github.com/NhuHuy-79/Algidy): keep groceries by fridge, freezer, and pantry, get reminded before they spoil, and see how much you actually eat.

Inventory stays on the device. There is no account, no ads, and no analytics.

## Features

- Inventory by location (Fridge, Freezer, Pantry, Other) or by category
- Manual add/edit with photo, dates, notes, and custom categories
- Barcode scan via camera, looked up on [Open Food Facts](https://world.openfoodfacts.org/)
- Expiry-date OCR from a live photo or the library
- Search with recent queries
- Mark items eaten or wasted, including multi-select
- Analytics: expired vs expiring, weekly expiry bars, freshness mix, eaten vs wasted
- Daily expiry notifications and an optional weekly report
- Face ID / passcode lock
- JSON backup export/import and delete-all
- English (US) and Simplified Chinese, plus a follow-system option
- Home Screen widgets for this week's expiring food and weekly counts

## Requirements

- Xcode 16 or newer
- iOS 17+
- Camera, Photos, Face ID, and Notifications permissions as you use those features

## Build

```bash
xcodegen generate
open Shelfie.xcodeproj
```

Select the **Shelfie** scheme, pick your development team, and run on an iPhone simulator or device.

If command-line `xcodebuild` fails with a CoreSimulator / asset catalog runtime mismatch, open the project in Xcode and run from there. That error is from this Mac's simulator runtime, not from the Shelfie sources.

Widgets share data through the App Group `group.com.xiaotwu.shelfie`. On a physical device, enable that App Group for both the app and the widget extension.

## Architecture

- **SwiftUI** for the interface (in place of Material You)
- **SwiftData** for local inventory, categories, and search history
- **Vision** for barcodes and date OCR
- **UserNotifications** for daily/weekly reminders
- **WidgetKit** for Home Screen widgets
- **Open Food Facts** only when you scan a barcode

## Privacy

Camera access is used for barcode scanning and OCR. Product lookups go to Open Food Facts. Everything else stays on the device.
