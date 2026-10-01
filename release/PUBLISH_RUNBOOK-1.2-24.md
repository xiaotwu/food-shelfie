# Publication preparation — 1.2 (24)

Gate: do not remove 1.1 (20) from review until the final 1.2 (24) archive has passed validation, upload has completed, and build 24 is processed/selectable in App Store Connect. Root sends the final ready signal. No product code, simulator, or device operations belong to this preparation step.

Observed existing state (read-only, September 30, 2026):
- App 6806936881, Food Shelfie. Browser account logged in.
- Version 1.1 / build 20 Waiting for Review; submission 48dbf8cb-156b-4b1e-bd98-52eaad3dac13.
- Automatically release this version is selected.
- Existing attachment Shelfie-AppReview-1.1-19.mp4 is from build 19; never describe it as build 24 footage.
- TestFlight internal groups: internal-group (a3419156-024d-46d4-9d6b-80d32f30595e) and phone-test (e7718dd7-3447-4430-af77-65e253e17cf0). Existing build 20 is assigned to both. One existing tester is shown; no external group exists. Preserve tester membership.
- Store language shown: English (U.S.). Language menu locked while pending review; Simplified Chinese localization existence has not been verified.
- iPhone Media Manager currently shows a 6.5-inch main slot with three old screenshots (first full preview 1242×2688). There is no visible 6.9-inch slot in the locked editor. iPad main slot is 13-inch with three old screenshots (first full preview 2048×2732).

After build-ready signal:
1. Verify build 24 version 1.2, processing/export-compliance status and native screenshots supplied by Root.
2. Remove pending version 1.1 from review, update the editable version to 1.2 and save. Preserve contacts, privacy, pricing and existing account setup.
3. Inspect unlocked Media Manager before choosing uploads. Prefer the current 6.9-inch iPhone and 13-inch iPad slots with Root’s native 1320×2868 and 2064×2752 screenshots. If UI still exposes only 6.5-inch for iPhone, inspect its accepted sizes/error text; do not stretch screenshots or claim a dimension is accepted without the upload result. Ask Root for a supported native capture when needed. Replace old-layout images in every actually populated size/localization; verify final preview/counts after save.
4. Use APP_DESCRIPTION-1.2-24.txt, relevant language sections of WHATS_NEW-1.2-24.txt if a What's New field exists, and APP_REVIEW_NOTES-1.2-24.txt. All are under 4000 characters. Description has no stale 28-day scheduling promise. Add/verify language localizations based on unlocked UI and supplied native images.
5. Select build 24. Preserve no-login review setting. Old video may remain only with explicit old-build disclosure; it cannot substantiate new text-only scan behavior.
6. Assign build 24 to the two existing TestFlight internal groups; retain old builds and testers. Set WHAT_TO_TEST-1.2-24.txt, inspect Beta App Review/export-compliance requirements, and do not invent external groups or invite additional people.
7. Read back version, build, description, review notes, screenshots and automatic release choice after saving/reloading. Submit for App Review only after all required fields are valid.
8. Save official submission result and current TestFlight status, with screenshots/logs. Waiting for Review is not approval or public availability. Record any validation/authentication blocker exactly.

Known validation boundary: one physical device only; two-device CloudKit sync acceptance remains pending. Local production schema deployment has succeeded. Final build 24 test/device/archive/upload evidence is supplied by Root when ready.
