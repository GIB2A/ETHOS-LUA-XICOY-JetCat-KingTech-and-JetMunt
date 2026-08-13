# Publishing checklist

- [ ] Review the complete diff.
- [ ] Verify the canonical source hash.
- [ ] Verify archive hashes.
- [ ] Extract and test every ZIP.
- [ ] Test manual installation.
- [ ] Test ETHOS Suite only if a validated package exists.
- [ ] Test on a radio.
- [ ] Create the commit.
- [ ] Push branch `main` after explicit authorization.
- [ ] Verify GitHub Actions after the push.
- [ ] Create the release tag matching `VERSION`.
- [ ] Push the tag.
- [ ] Create the GitHub Release.
- [ ] Attach ZIP files.
- [ ] Attach `SHA256SUMS.txt`.
- [ ] Mark the release stable.
- [ ] Verify download links.

Suggested commands are documented in [Releasing](RELEASING.md); they require
explicit authorization.

Repository: https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry
