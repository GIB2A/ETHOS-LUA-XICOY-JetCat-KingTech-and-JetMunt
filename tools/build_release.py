from __future__ import annotations
import hashlib, shutil, sys, tempfile, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
SOURCE = ROOT / "src/GIB2A/main.lua"
EXPECTED_HASH = "3CE21D266AC3745818D5ED7011F171E55F88BE129805605A2DC0F0C885EB8CB6"
EXPECTED_SIZE = 93474
EXPECTED_LINES = 2761
if VERSION != "26.2.2": raise SystemExit("Unexpected VERSION")
raw = SOURCE.read_bytes()
if hashlib.sha256(raw).hexdigest().upper() != EXPECTED_HASH: raise SystemExit("Source hash mismatch")
if len(raw) != EXPECTED_SIZE or len(raw.splitlines()) != EXPECTED_LINES: raise SystemExit("Source format mismatch")
if raw.startswith(b"\xef\xbb\xbf") or b"\r" in raw: raise SystemExit("Source must be UTF-8 without BOM and LF-only")
raw.decode("utf-8")

out = ROOT / "release" / "V26.2.2"
out.mkdir(parents=True, exist_ok=True)
timestamp = (2026, 7, 31, 0, 0, 0)

def make_zip(path, entries):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for name, data in sorted(entries):
            info = zipfile.ZipInfo(name, timestamp)
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            zf.writestr(info, data)
    with zipfile.ZipFile(path) as zf:
        mains = [n for n in zf.namelist() if n == "main.lua" or n.endswith("/main.lua")]
        if len(mains) != 1 or hashlib.sha256(zf.read(mains[0])).hexdigest().upper() != EXPECTED_HASH:
            raise SystemExit(f"Extracted source validation failed: {path.name}")

sd = out / "GIB2A-Xicoy-ProHub-Widget-V26.2.2-SD.zip"
make_zip(sd, [("SCRIPTS/GIB2A/main.lua", raw)])
archives = [sd]
manifest = ROOT / "packaging/ethos_lua_manifest.json"
if manifest.exists():
    suite = out / "GIB2A-Xicoy-ProHub-Widget-V26.2.2-ETHOS-Suite.zip"
    make_zip(suite, [
        ("ethos_lua_manifest.json", manifest.read_bytes()),
        ("main.lua", raw),
        ("README.md", (ROOT / "README.md").read_bytes()),
        ("CHANGELOG.md", (ROOT / "CHANGELOG.md").read_bytes()),
        ("INSTALLATION.md", (ROOT / "docs/INSTALLATION.md").read_bytes()),
    ])
    archives.append(suite)
else:
    print("SKIP: no validated ETHOS Suite manifest; manual SD package only")
lines = [f"{hashlib.sha256(path.read_bytes()).hexdigest().upper()}  {path.name}" for path in sorted(archives)]
(out / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="ascii", newline="\n")
(out / "GITHUB_RELEASE_NOTES.md").write_bytes(
    (ROOT / "docs/release-notes/V26.2.2.md").read_bytes()
)
attachment_lines = "\n".join(f"- {path.name}" for path in sorted(archives))
handoff = f"""GIB2A V26.2.2 — GitHub Desktop handoff

Local repository:
{ROOT}

GitHub repository:
https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry

Git remote:
https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry.git

Branch:
release/v26.2.2-prep

Recommended commit message:
Release GIB2A V26.2.2

Recommended commit description:
Prepare the GIB2A V26.2.2 public release with the validated Lua source, updated English and French documentation, compatibility information, validation tools, GitHub templates, release notes and reproducible SD and ETHOS Suite packages.

Files to attach to the future GitHub Release:
{attachment_lines}
- SHA256SUMS.txt

SD ZIP SHA-256: {hashlib.sha256(sd.read_bytes()).hexdigest().upper()}
ETHOS Suite ZIP SHA-256: {hashlib.sha256(suite.read_bytes()).hexdigest().upper() if manifest.exists() else "not built"}
Official main.lua SHA-256: {EXPECTED_HASH}

Future release title: GIB2A V26.2.2
Future tag: v26.2.2
Future Pull Request:
https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry/compare/main...release/v26.2.2-prep

Repository description:
FrSky ETHOS Lua turbine telemetry widget for Xicoy ProHub with multi-ECU status support.

Topics:
frsky, ethos, lua, telemetry, rc-jet, turbine, xicoy, jetcat, kingtech, swiwin, enjet, linton

Before publication:
- Complete the radio tests.
- Create the commit in GitHub Desktop.
- Publish the preparation branch.
- Create the Pull Request to main.
- Verify GitHub Actions.
- Merge into main after approval.
- Create tag v26.2.2.
- Create the GitHub Release.
- Attach both ZIP files and SHA256SUMS.txt.
- Verify the public downloads.
"""
(out / "GITHUB_DESKTOP_HANDOFF.txt").write_text(
    handoff, encoding="utf-8", newline="\n"
)
for path in archives:
    print(f"{path.name}: {path.stat().st_size} bytes, SHA-256 {hashlib.sha256(path.read_bytes()).hexdigest().upper()}")
print("Build: PASS")
