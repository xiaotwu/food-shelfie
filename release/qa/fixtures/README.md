# Backup compatibility fixtures

These small, hand-authored JSON files represent Shelfie's versioned backup formats. They are compatibility fixtures, not user data or evidence that an old released binary exported the files.

- `backup-v1.json`: categories, foods and search history; no custom locations or quantity fields.
- `backup-v2.json`: custom location and food location reference; quantity defaults to one piece on restore.
- `backup-v3.json`: explicit fractional quantity, unit and owner.
- `backup-v4.json`: opening date, opening shelf life, low-stock threshold and a completed shopping item.

All dates use ISO 8601 UTC and IDs remain stable across fixtures. The custom category deliberately avoids built-in category aliases so migration does not rewrite its ID. Version 1 restores the legacy pantry enum to the deterministic built-in pantry location. Later versions keep their custom location.

`ShelfieTests/BackupFixtureTests.swift` reads these files from the test bundle, imports them into isolated in-memory stores, checks defaults and references, and verifies a version 4 export/import round trip. Separate cases cover invalid export data, missing photos and serialized-byte/file-size guards.
