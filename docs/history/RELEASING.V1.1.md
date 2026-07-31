# Releasing

## Versioning
- This project uses *Semantic Versioning*.
- Tag format: `vX.Y.Z` (example: `v1.1.0`).
- Keep these files consistent:
  - `VERSION`
  - `CHANGELOG.md`
  - `README.md`

## Create a release
1. Update `VERSION` and `CHANGELOG.md`.
2. Commit the changes.
3. Create a tag:
   - `git tag vX.Y.Z`
4. Push commits and tags:
   - `git push`
   - `git push --tags`
5. GitHub → Releases → Draft a new release.
6. (Optional) Attach a distribution ZIP that preserves the SD card structure:

   `SCRIPTS/GIB2A/main.lua`
