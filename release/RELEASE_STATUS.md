## Current release closeout — 1.2 (24)

September 30, 2026 release closeout authorized by the user:

- Fixed equal eight-point leading/trailing padding in the global navigation container; controls remain 44×44 points. Settings and all five subpage titles are centered. Adaptive overflow keeps long titles intact and preserves search/sort/add.
- Final navigation checks: seven scoped cases pass across phone rotation, phone Settings, and iPad normal/maximum accessibility text. See [UI validation](qa/build24-navigation-ui-validation.md) and [measured geometry](qa/build24-toolbar-geometry.json). Earlier failed prevalidation runs are documented separately, not claimed as passing.
- 85 unit tests passed, zero failures/skips/runtime warnings: [unit summary](qa/build24-unit-summary.json). Final current-source Release archive and physical Debug build are warning-free; iPhone installation/normal launch/process verification succeeded without editing inventory: [archive/device summary](qa/build24-archive-device-summary.json).
- Upload succeeded at 17:04:33 PDT. App Store Connect processed version 1.2 build 24. What to Test was saved; both existing internal groups are Testing: [upload summary](qa/build24-upload-summary.json), [internal distribution status](qa/build24-internal-distribution-summary.json). No tester installation is claimed.
- Refreshed native store screenshots are ready: five iPhone and five iPad images, captured from the normal build 24 app with fictional demo inventory. See [capture manifest](qa/store-screenshots/manifest.json). The old 1.1 (20) review was canceled after final validation/upload. The editable version and review information are now saved as 1.2; automatic release is selected. Screenshot upload/build selection and final submission are in progress. This is not an approval or public-availability claim.
- Raw account-page screenshots, accessibility dumps and upload logs remain local because they contain account identifiers. Only sanitized publication summaries are intended for GitHub.

The entries below are historical evidence and do not override this current record.

## Resume after reconnection

1. Install current debug app and launch with `--initialize-cloudkit-schema`. This creates schema using an isolated empty temporary store, without exporting the user's inventory. Confirm `SHELFIE_SCHEMA_INITIALIZED`, then inspect development types and deploy the reviewed schema to production.
2. Confirm user is ready, record the physical device from app launch through core flows and permissions; inspect the resulting video before uploading to App Review. Use synthetic food names and avoid personal screens.
3. Verify remaining iPhone and iPad screenshots. Update testing notes with only completed checks and attach the recording; respond to Apple's seven requested points.
4. Resubmit the corrected version. Automatic release after approval is selected; approval and live availability must be independently confirmed.

`xcrun devicectl device capture screen-record --device [device identifier redacted] --destination /absolute/path/review.mp4` records until Ctrl+C, which saves the video.

The working tree contains both pre-existing user changes and this session's fixes. Only the privacy-policy commit has been pushed; do not discard or overwrite uncommitted files.

## Scanner follow-up — build 18

User reported lookup completing without product information. Their supplied barcode 04964406 returned HTTP 404 / status 0 / product not found from the existing Open Food Facts endpoint. A known barcode 3017620422003 returned HTTP 200 and Nutella metadata, so the service was reachable from this Mac; this does not verify phone networking.

Changed scanner-to-entry presentation to wait for full-screen dismissal, clear stale edit state, and retain an explicit not-found notice on the entry form. Reworked OCR to resume its continuation exactly once after synchronous Vision completion on a background queue. Debug device build 1.1 (18) succeeded. The 15-test suite passed on iPhone Air / iOS 26.5 after presentation/OCR changes; these tests do not cover physical camera or UI transitions. Final notice UI compiled in device build. True-device retest remains necessary. Uploaded review build is still 17; do not resubmit it as though it contains build 18 fixes.

## Confirmed prefill follow-up — build 19

Correct code from packaging photo: 04963406. Open Food Facts returned Coke Original Taste, brand Coke and a product image (HTTP 200). User confirmed physical recognition but empty form remained on build 18.

Replaced separate Boolean sheet visibility and shared draft/edit state with a single identifiable EntryPresentation carrying its exact draft or existing record. Scanner result is queued until full-screen dismissal, then presented via sheet(item:). Manual add creates a fresh payload, avoiding stale scan data. DEBUG-only --qa-barcode argument exercises the real lookup/callback/presentation flow without relying on camera access during automation.

Built and installed 1.1 (19). On the physical iPhone 15 Pro, launched --qa-barcode 04963406 and visually confirmed the resulting entry form contains Coke Original Taste and the downloaded Coca-Cola image. Evidence: release/qa/build19-barcode-prefill.png. No inventory record was saved. This validates lookup and prefill, not physical camera detection; user will retest camera scanning. Relaunched normally to clear QA arguments. Preparing the new Release archive; App Store Connect still has build 17 selected until updated.

Build 19 Release archive succeeded at /tmp/shelfie-release19/Shelfie.xcarchive. Upload started using existing export options; log /tmp/shelfie-release19-upload.log. Confirm completion before claiming uploaded or selecting it for review.

Build 19 upload confirmed successful at 2026-09-29 17:38 PDT: Upload succeeded / EXPORT SUCCEEDED. App Store processing is pending; review selection still requires updating from 17.

## Physical review video and current submission checkpoint

Build 19 finished processing and is selected on the version 1.1 editor. Review notes were updated for build 19. The existing rejected submission still references build 17 until Update Review is completed; no resubmission or publication has been confirmed.

User supplied `/Users/xiaotwu/Downloads/ScreenRecording_09-29-2026 17-40-41_1.mov`, captured on iPhone 15 Pro / iOS 27.0. Reviewed the 155-second sequence: launch, camera permission settings, physical barcode scanning with successful product-name/photo autofill, editing and saving food, search/filter/sort, marking eaten, Insights, reminder settings and optional cloud/data settings. This confirms the actual camera-to-form regression is fixed. Date OCR and cross-device sync are not claimed as tested.

Full sequence converted to silent H.264 MP4, 1080 × 2340, 30 fps, about 18 MiB; original retained. Upload-ready file: `/Users/xiaotwu/Downloads/Shelfie-AppReview-1.1-19.mp4` (also `/tmp/shelfie-review-media/Shelfie-1.1-19-iPhone15Pro-iOS27.mp4`).

Attachment upload attempted through the supported browser file-chooser API. It failed because the Chrome ChatGPT extension does not have “Allow access to file URLs” enabled. User was asked to enable this setting. No attachment upload, review reply or resubmission has succeeded yet. Reconnect browser after the setting changes; attach video, save notes, reply to Apple's seven points, Update Review and Resubmit to App Review, then verify status. Automatic release after approval remains selected.

## Submission completed — 2026-09-29 17:58 PDT

User enabled file URL access. Video uploaded successfully both to App Review Information and to the seven-point reply on the original rejected submission. Reply sent at 17:56 PDT; its message attachment is visibly available to download. Exact reply saved in `release/APP_REVIEW_REPLY-1.1-19.txt`.

An initial Update Review exposed stale saved build 17 and old notes. Removed that review association before any actual submission, selected build 19 again, replaced Notes with the full numbered reply, saved, then reloaded to verify build 19, the new notes and video attachment persisted. Added this verified configuration to a new submission and clicked Submit for Review.

Apple confirmed “1 Item Submitted.” Final submission page shows version 1.1 (19), **Waiting for Review**, submitted Sep 29, 2026 at 5:58 PM. Submission ID: `7ef13942-854c-436f-9e78-a170ee94bac7`.

Review URL: https://appstoreconnect.apple.com/apps/6806936881/distribution/reviewsubmissions/details/7ef13942-854c-436f-9e78-a170ee94bac7

Proof: `release/qa/build19-waiting-for-review.png`. Automatic release after approval is selected. Apple approval and live App Store availability are pending; neither is claimed complete.

## Resumed icon publication task

User requested resuming the previously paused icon task. The selected design is `design/icon-concepts/10-fridge-clock-green.png`. App icon, app BrandMark and widget BrandMark are updated; the empty-shelf, lock and About brand images use rounded presentation. Existing build 20 archive is `/tmp/shelfie-release20/Shelfie.xcarchive`, version 1.1 (20).

Published only the six icon/resource/presentation changes to GitHub in `ab57aba` (Apply refined fridge and clock brand icon). Other pre-existing and release-fix working-tree changes remain untouched and uncommitted. HTTPS push confirmed `85dfa8f..ab57aba main -> main`.

Xcode Apple Accounts still shows “Sign in to your Apple Account” with no signed-in account. Existing build 20 upload log reports `exportArchive Failed to Use Accounts` / App Store Connect access required for team 9URWGD9Q86. User has been asked to sign in in the open Xcode Settings → Apple Accounts. No build 20 upload has succeeded. Build 19 was freshly checked and remains Waiting for Review.

Screenshot refresh was attempted on the icon QA simulator but a notification permission dialog blocks its UI snapshot. Do not claim screenshots refreshed. After account login, retry build 20 export/upload, confirm processing and new icon, then update the review build while retaining the existing video/notes and automatic-release setting. The existing recording shows build 19; describe build 20's icon-only difference honestly when reusing it.

## New icon submitted — 2026-09-29 23:57 PDT

After the user signed into Xcode, build 20 export/upload completed successfully (Upload succeeded / EXPORT SUCCEEDED). App Store Connect validated version 1.1 (20), and existing internal TestFlight groups internal-group and phone-test are associated. What to Test was saved for the refreshed branding.

Canceled the build 19 pending submission, selected build 20, and saved updated notes. Reloaded the editor and verified build 20, the new fridge/apple/clock icon, the retained Shelfie-AppReview-1.1-19.mp4 attachment, and automatic release after approval. Notes explicitly state that the physical video and physical testing used build 19; build 20 changes only icon/brand-image presentation and retains the same core functionality. Exact notes: release/APP_REVIEW_NOTES-1.1-20.txt.

Apple confirmed 1 Item Submitted. Final review page shows 1.1 (20), Waiting for Review, submitted Sep 29, 2026 at 11:57 PM. Submission ID: 48dbf8cb-156b-4b1e-bd98-52eaad3dac13.

Review URL: https://appstoreconnect.apple.com/apps/6806936881/distribution/reviewsubmissions/details/48dbf8cb-156b-4b1e-bd98-52eaad3dac13

Proof: release/qa/build20-waiting-for-review.jpg (local-only original; excluded from the public repository). GitHub icon changes are already pushed in ab57aba. Apple approval and public availability remain pending. Existing product screenshots have not been refreshed.

## Next product stage — 2026-09-30

Implemented local development version 1.2 (21): quantity/unit tracking, partial consumption, repeat purchase, undo, reliable save feedback and backup v3 with legacy defaults. Three agents handled Entry, Inventory/Search and Data Settings; main agent integrated model/backup/localization and validation. 24 tests passed on iOS 26.5, including a pre-quantity persistent-store migration. Debug UI walkthrough and Release simulator compile passed. Full details: release/NEXT_STAGE-1.2.md. Latest undo proof: release/qa/build21-undo-visible.jpg.

No App Store upload/review replacement in this stage. Build 20's prior submission is unchanged by this work; its current external review status was not rechecked. Build 21 physical-device/TestFlight and cross-device sync testing, plus new CloudKit production fields, remain before release.

## CloudKit phase 2 production schema — 2026-09-30

Built current Debug app for the connected iPhone 15 Pro / iOS 27.0 at `/tmp/shelfie-phase2-device` and launched `--initialize-cloudkit-schema`. Maintenance launch skips the user's persistent container, RootView, pruning, reminders and widget refresh. The helper used a new empty temporary Core Data store and printed `SHELFIE_SCHEMA_INITIALIZED`.

Reviewed official CloudKit Console deployment diff for `iCloud.com.xiaotwu.shelfie`: addition of `CD_quantity`, `CD_unitRaw` plus its asset companion, `CD_openedDate`, `CD_openedShelfLifeDays`, `CD_lowStockThreshold`; creation of `CD_ShoppingItemRecord` and corresponding indexes. No existing fields/types were removed or changed. Existing record type grants were unchanged; the new type uses the same generated grants for the app's private CloudKit database.

Deployment succeeded with Console confirmation “Changes Deployed — The schema is deployed to Production.” Production list then showed FoodItemRecord 38 fields (previously 32) and ShoppingItemRecord 17 fields. Evidence: `release/qa/cloudkit-phase2-production-deployed.png`, baseline schema `cloudkit-production-before-phase2.ckdb`, reviewed diff `cloudkit-phase2-deployment-diff.txt`, physical console marker `cloudkit-schema-initialization-phase2.log`.

This confirms production schema deployment only. Cross-device record synchronization is still not claimed as tested. No App Store or TestFlight upload/review replacement was performed; pending 1.1 (20) was not altered. Current Debug app is installed on the physical device; the schema-only launch did not open its inventory.

## Latest normal physical-device launch — 2026-09-30

Latest Debug app 1.2 (21) compiled successfully in `/tmp/shelfie-phase2-device`, installed over the existing app on iPhone 15 Pro / iOS 27.0, and launched normally without schema or QA arguments. Launch console reported success, process inspection found Shelfie running, and a physical screenshot showed the normal Shelf screen with an empty active inventory, shopping/history links and floating dock. No storage recovery error or launch crash observed. No inventory editing, App Store submission changes or TestFlight upload performed.

Evidence: `release/qa/build21-device-build.log`, `build21-device-install.log`, `build21-device-launch.log`, `build21-device-running.json`, `build21-device-launch.png`. This is a launch smoke check; scanner, long-duration reminders and cross-device sync are not claimed as physically retested.

## Read-only App Store review status check — 2026-09-30

Official App Store Connect submission `48dbf8cb-156b-4b1e-bd98-52eaad3dac13` currently shows **Waiting for Review**, one submitted item **iOS App 1.1 / 1.1 (20)**. Submission date displayed Sep 29, 2026 at 11:57 PM. This is still awaiting review; approval and public availability are not claimed. No submission, build selection, review message, or App Store metadata was changed; local 1.2 (21) was not uploaded.

Evidence: `release/qa/build20-review-status-2026-09-30.png` and `.txt`. Source: https://appstoreconnect.apple.com/apps/6806936881/distribution/reviewsubmissions/details/48dbf8cb-156b-4b1e-bd98-52eaad3dac13
