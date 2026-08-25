# Publishing checklist

- [ ] Build release packages.
- [ ] Validate SD ZIP.
- [ ] Validate ETHOS Suite ZIP.
- [ ] Verify `main.lua` SHA.
- [ ] Verify package SHA-256.
- [ ] Verify installation instructions match actual filenames.
- [ ] Verify README download links.
- [ ] Review the complete diff.
- [ ] Test manual SD installation.
- [ ] Test ETHOS Suite installation.
- [ ] Verify radio.
- [ ] Create the commit.
- [ ] Push branch `main` after explicit authorization.
- [ ] Verify GitHub Actions after the push.
- [ ] Create the release tag matching `VERSION`.
- [ ] Push the tag.
- [ ] Create the GitHub Release.
- [ ] Attach the SD and ETHOS Suite ZIP files.
- [ ] Attach `SHA256SUMS.txt`.
- [ ] Mark the release stable.
- [ ] Verify GitHub Release assets.
- [ ] Verify download links.
- [ ] Publish only after authorization.

Suggested commands are documented in [Releasing](RELEASING.md); they require
explicit authorization.

Repository: https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry
