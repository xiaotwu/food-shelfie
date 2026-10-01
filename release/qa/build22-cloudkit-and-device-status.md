# Build 22 CloudKit and physical device evidence

- Container: iCloud.com.xiaotwu.shelfie, team 9URWGD9Q86.
- DEBUG maintenance launch used a fresh empty temporary Core Data store, with user ModelContainer / RootView / pruning / scheduling bypassed. Console printed SHELFIE_SCHEMA_INITIALIZED.
- Reviewed and deployed only one added shopping field: CD_inventoryFoodID STRING, with Queryable / Searchable / Sortable indexes. No security-role changes or deleted fields.
- CloudKit Console reported Changes Deployed to Production. Production CD_ShoppingItemRecord has 18 fields and CD_inventoryFoodID is visibly present with all three indexes.
- Final normal Debug build succeeded with zero warnings; bundle com.xiaotwu.shelfie, version 1.2 (22).
- Installed on paired iPhone 15 Pro / iOS 27.0 without uninstalling, wiping, injecting inventory or changing App Store submission.
- Normal launch passed no schema or QA arguments. Process 4020 remained running; screenshot shows normal Shelf and new first-item guidance, with no startup/storage error.
- Only one physical device available. Two-device CloudKit sync acceptance remains pending; no claim of completed cross-device verification.

Evidence files: build22-cloudkit-device-build.log, build22-cloudkit-device-install.log, build22-cloudkit-schema-init.log, build22-cloudkit-deployment-diff.txt, build22-cloudkit-production-deployed.png, build22-cloudkit-production-fields.txt, build22-device-build.log, build22-device-install.log, build22-device-launch.log, build22-device-running.json, build22-device-launch.png.

Final device reinstall includes entry.name / entry.scroll accessibility identifiers; normal build, install, launch and screenshot evidence overwritten with this final source. No schema redeployment needed.

Final device reinstall also includes FoodCard full rectangle contentShape for reliable taps between text on cards without photos. No schema or QA launch arguments.

Final physical device source also includes Inventory highPriorityGesture LongPressGesture selection fix alongside FoodCard contentShape. Normal launch only; no inventory editing.
