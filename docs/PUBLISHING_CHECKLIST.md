# Publishing checklist

- [ ] Review the complete diff.
- [ ] Verify the canonical source hash.
- [ ] Verify archive hashes.
- [ ] Extract and test every ZIP.
- [ ] Test manual installation.
- [ ] Test ETHOS Suite only if a validated package exists.
- [ ] Test on a radio.
- [ ] Create the commit.
- [ ] Publish branch `release/v26.2.2-prep`.
- [ ] Open the Pull Request to `main`.
- [ ] Verify GitHub Actions and merge after approval.
- [ ] Create tag `v26.2.2`.
- [ ] Push the tag.
- [ ] Create the GitHub Release.
- [ ] Attach ZIP files.
- [ ] Attach `SHA256SUMS.txt`.
- [ ] Mark the release stable.
- [ ] Verify download links.

Suggested commands are documented in [Releasing](RELEASING.md); they require
explicit authorization.

Repository: https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry

Pull Request:
https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry/compare/main...release/v26.2.2-prep
