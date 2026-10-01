# Build 24 navigation UI validation

Final navigation implementation is approved by the scoped UI checks below. These are separate runs, not a single seven-test run. All builds used CODE_SIGNING_ALLOWED=NO and the dedicated simulators; no user food or shopping records were created or deleted. Sort was restored to expiry date. iPad content size was restored to accessibility-extra-extra-extra-large after normal-font checks.

| Device / text size | Test | Result / seconds | Result bundle |
|---|---|---|---|
| Phone 402 pt / normal | Five Settings subpages, centered titles, symmetry, touch sizes, overflow menu and Back | PASS / 106.434 | /tmp/shelfie-release24-phone-center-8.xcresult |
| Phone 402 pt / normal | Rotation: portrait collapsed → landscape expanded → portrait collapsed | PASS / 16.284 | /tmp/shelfie-release24-phone-adaptive.xcresult |
| Phone 402 pt / normal | Collapsed Search, Sort, Add routes, full title and cancellation | PASS / 55.612 | /tmp/shelfie-release24-phone-adaptive-2.xcresult |
| iPad 834 pt / maximum accessibility | Global Search, Sort, Add routes; inline headings; Insights cards | PASS / 103.273 | /tmp/shelfie-release24-ipad-maxfont.xcresult |
| iPad 834 pt / maximum accessibility | Five Settings subpages, centered titles, symmetry, touch sizes, Back | PASS / 74.166 | /tmp/shelfie-release24-ipad-maxfont.xcresult |
| iPad 834 pt / normal | Global Search, Sort, Add routes and cancellation | PASS / 78.561 | /tmp/shelfie-release24-ipad-normalfont.xcresult |
| iPad 834 pt / normal | Five Settings subpages, centered titles, symmetry, touch sizes, Back | PASS / 67.384 | /tmp/shelfie-release24-ipad-normalfont.xcresult |

## Geometry and evidence

The five Settings pages are Notifications, Appearance, Data, More, and About Shelfie. Tests require title center within two points of the screen center, full title visibility within navigation bounds, no overlap with native Back or actions, and stable frames before measurement. Phone titles measured center errors from -0.20 to -0.05 points; iPad maximum-font titles from -0.25 to 0 points. Every tested toolbar control measured 44×44 points. Actual outer visual host bounds were 60×44 collapsed or 172×44 expanded, with eight-point leading and trailing insets. Icons remained centered in their touch areas.

Measurements: `build24-toolbar-geometry.json`.

Summary JSON: `build24-phone-settings-centering-summary.json`, `build24-phone-adaptive-initial-summary.json`, `build24-phone-adaptive-routes-summary.json`, `build24-ipad-maxfont-ui-summary.json`, `build24-ipad-normalfont-ui-summary.json`.

Screenshots and accessibility trees use prefixes `build24-phone-centered-settings-*`, `build24-phone-adaptive-*`, `build24-ipad-maxfont-centered-settings-*`, `build24-ipad-normalfont-centered-settings-*`, and corresponding `global-*` captures. Representative final screenshots: `build24-phone-centered-settings-data.png`, `build24-ipad-maxfont-centered-settings-more.png`, `build24-ipad-normalfont-centered-settings-notifications.png`, `build24-phone-adaptive-notifications-landscape-expanded.png`.

## Prevalidation failures and corrections

Earlier phone runs correctly exposed native Menu conversion to a 48×36 accessibility button and unequal four/eight-point visual insets. The first custom UIHostingController bridge then offset/clipped the icon and later interfered with push navigation; those builds failed and are not release evidence. The final UIKit UIHostingConfiguration container retains the original SwiftUI actions, explicit fixed visual bounds and centered 44-point controls without additional child-controller containment. The container identifier was moved to the actual visual host before the successful final runs.

Test corrections preserved the product requirements: dismiss the system overflow popover by tapping page content outside its true anchored bounds, rather than its overlapping navigation title; wait for actual stable title/control geometry instead of merely the NavigationBar identifier; allow twenty seconds for slow accessibility snapshots while still requiring at least half a second of identical frames. Centering applies strictly to Settings root and its five subpages. Shelf and Insights intentionally retain their leading inline headings, with visibility, same-row and collision checks. The initial phone adaptive bundle consequently has one passing rotation case and one failed over-broad Shelf-center assertion; the corrected route case passes in its separate final bundle. No touch-size, symmetry or Settings centering assertion was weakened.

Final test source: `ShelfieUITests/LayoutFlowTests.swift`. No product changes were made by the UI verification agent during this final run. No additional inventory regression was repeated because this release request changed only navigation layout.
