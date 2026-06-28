# Release Checklist

1. Choose the next version and update `CC.BUILD.version` plus TOC Version.
2. Add schema migration only when persistent structure changes.
3. Replace module hard-coded versions with `CC.version`; do not introduce new build literals.
4. Update CHANGELOG and README.
5. Update affected developer documents.
6. Regenerate function/event/command indexes.
7. Parse all Lua files.
8. Validate TOC load order and file existence.
9. Validate media manifests and formats.
10. Run fresh-install and upgrade smoke tests.
11. Run `/cc devreport` in game.
12. Regenerate `FILE_MANIFEST.txt` with hashes.
13. Regenerate `QC_REPORT.txt`.
14. Build ZIP with one top-level `CreshChat` folder.
15. Test ZIP CRC and inspect path lengths.
16. Confirm no source previews, temporary files or duplicate addon folders are included.
