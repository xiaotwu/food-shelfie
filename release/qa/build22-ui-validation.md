# Build 22 UI validation

Device: dedicated iPad simulator `10D4A587-B93A-4931-93A6-FB6333055804`, iOS 26.5, maximum accessibility text size, English UI. No user-device UI test, store erase or existing Milk edits were performed.

## Passed runs

These four tests passed across two runs; they are not four passes from one bundle.

- Existing landscape/portrait shelf, center tap detail, separate package/opened/reminder dates, shopping state restore, history: **PASS, 167.444 s**, `/tmp/shelfie-final-ui-2.xcresult`.
- Strict global toolbar/title/card geometry, sort routing, Settings Appearance Back, Settings search and Insights manual Add: **PASS, 85.284 s**, same bundle.
- New no-expiry food, optional More information expansion/collapse, Save and add another persistent save and form reset, second save, both card center taps and Unknown package dates, owned-data cleanup: **PASS, 228.577 s**, `/tmp/shelfie-final-new-ui-4.xcresult`.
- Shopping confirmation cancellation preserves pending, explicit no-expiry choice required, atomic conversion updates Bought, duplicate conversion disabled, exactly one batch, detail and owned-data cleanup: **PASS, 139.084 s**, same new-flow bundle. This bundle reports **TEST SUCCEEDED**, 2/2.

The final new-flow bundle reported no warnings. The old-flow run reported no Swift compiler warnings; its build emitted one AppIntents metadata-extraction warning for the UI test runner (no AppIntents framework dependency).

## Issues found and resolved

1. Initial signed simulator installation selected the App Group store, which was empty. Existing Milk remained in the earlier unsigned simulator installation's Application Support fallback store. Re-running with the original `CODE_SIGNING_ALLOWED=NO` configuration restored the original QA store without copying or editing databases. This was an installation configuration difference, not loss of Milk.
2. SwiftUI DisclosureGroup propagated `entry.moreInformation` to child Toggle identifiers. The test now locates the actual Opened switch by its English accessibility label; it still checks existence, hitability and collapse.
3. iPad native confirmation popovers omit a Cancel row. Cancellation is tested by tapping outside on the navigation title and asserting the popover disappears while the shopping item remains pending.
4. Product fix: photo-free FoodCard now defines a rectangular content shape, making its center and blank areas actionable.
5. Product fix: Inventory cards now prioritize LongPressGesture over Button tap so long press enters selection instead of opening detail. The final run proves both long press deletion and ordinary center tap detail work.

Assertions for hitability, navigation titles, toolbar/card geometry, saved data and duplicate conversion were retained. No blind tap retries were added.

## Cleanup and evidence

Only unique QA First/Second/Shop names created by these tests were deleted; temporary previous-run cleanup steps were removed after successful cleanup. Read-only persisted verification is `build22-ui-inventory-readback.json`: one active Milk, quantity 1, original package/opening dates, opening lifetime 3 days; one completed Milk shopping row, quantity 1; **zero QA food and shopping rows remain**.

Machine summaries: `build22-ui-existing-summary.json`, `build22-ui-new-flows-summary.json`.

Key screenshot and corresponding `-AX.txt` evidence:

- `build22-existing-iPad-landscape-shelf.png`
- `build22-existing-iPad-landscape-detail-dates.png`
- `build22-existing-iPad-portrait-shelf.png`
- `build22-existing-iPad-portrait-detail-dates.png`
- `build22-existing-global-insights-toolbar.png`
- `build22-new-entry-save-another-reset.png`
- `build22-new-entry-after-card-center-QA-First-4237B4.png`
- `build22-new-entry-no-expiry-QA-First-4237B4.png`
- `build22-new-entry-no-expiry-QA-Second-4237B4.png`
- `build22-new-shopping-conversion-linked-once.png`
- `build22-new-shopping-converted-food.png`

Full attachment exports remain in `/tmp/shelfie-final-ui-2-attachments` and `/tmp/shelfie-final-new-ui-4-attachments`.
