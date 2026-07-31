from __future__ import annotations
import hashlib, json, re, shutil, subprocess, sys, tempfile, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src/GIB2A/main.lua"
EXPECTED_VERSION = "26.2.2"
EXPECTED_HASH = "3CE21D266AC3745818D5ED7011F171E55F88BE129805605A2DC0F0C885EB8CB6"
EXPECTED_SIZE = 93474
EXPECTED_LINES = 2761
errors = []

def check(ok, message):
    print(("PASS: " if ok else "FAIL: ") + message)
    if not ok: errors.append(message)

raw = SOURCE.read_bytes()
check((ROOT / "VERSION").read_text(encoding="utf-8").strip() == EXPECTED_VERSION, "version")
check(hashlib.sha256(raw).hexdigest().upper() == EXPECTED_HASH, "source SHA-256")
check(len(raw) == EXPECTED_SIZE, "source size")
check(len(raw.splitlines()) == EXPECTED_LINES, "source line count")
check(not raw.startswith(b"\xef\xbb\xbf"), "no UTF-8 BOM")
try:
    text = raw.decode("utf-8")
    check(True, "UTF-8")
except UnicodeDecodeError:
    text = ""
    check(False, "UTF-8")
check(b"\r" not in raw, "LF line endings")
check('local WIDGET_VERSION = "26.2.2"' in text, "internal version")
check(re.search(r'key\s*=\s*"GIB2A"', text) is not None, "widget key")
reads = re.findall(r'storage\.read\(\s*"([^"]+)"', text)
writes = re.findall(r'storage\.write\(\s*"([^"]+)"', text)
check(len(reads) == 43, "43 storage.read keys")
check(len(writes) == 43, "43 storage.write keys")
check(reads == writes, "storage order identical")
check(len(reads) == len(set(reads)) and len(writes) == len(set(writes)), "no storage duplicates")
check(not re.search(r"PERF\s*DEBUG|PERF DEBUG|PERF panel", text, re.I), "no PERF DEBUG")
check("print(" not in text, "no development print")
local_path_re = re.compile(r"[A-Za-z]:\\\\" + "|" + "/" + "mnt/")
check(not local_path_re.search(text), "no local paths in Lua")
paint = re.search(r"local function paint\(widget\)(.*?)\nend\n", text, re.S)
check(bool(paint) and "system.getSource" not in paint.group(1) and ":value(" not in paint.group(1), "paint reads no sources")
for executable in ("luac", "lua"):
    path = shutil.which(executable)
    if path:
        args = [path, "-p", str(SOURCE)] if executable == "luac" else [path, "-e", f"assert(loadfile([[{SOURCE}]]))"]
        check(subprocess.run(args, capture_output=True).returncode == 0, "Lua syntax")
        break
else:
    print("SKIP: Lua interpreter/compiler unavailable")

tracked_text = []
for path in ROOT.rglob("*"):
    if path.is_file() and ".git" not in path.parts and "archive" not in path.parts and "release" not in path.parts:
        if path.suffix.lower() in {".md", ".py", ".ps1", ".yml", ".yaml", ".txt", ""}:
            try: tracked_text.append((path, path.read_text(encoding="utf-8")))
            except UnicodeDecodeError: pass
check(not any(local_path_re.search(value) for _, value in tracked_text), "no local paths in release files")
secret_re = re.compile(r"(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16})")
check(not any(secret_re.search(value) for _, value in tracked_text), "no obvious secrets")
required_docs = ["README.md","README_FR.md","CHANGELOG.md","docs/COMPATIBILITY.md","docs/CONFIGURATION.md","docs/INSTALLATION.md","docs/DISCLAIMER.md","docs/TROUBLESHOOTING.md","docs/release-notes/V26.2.2.md"]
check(all((ROOT / item).is_file() for item in required_docs), "required documentation")
bad_links = []
link_re = re.compile(r"\[[^\]]+\]\((?!https?://|mailto:|#)([^)]+)\)")
for path, value in tracked_text:
    if path.suffix.lower() != ".md": continue
    for link in link_re.findall(value):
        clean = link.split("#", 1)[0]
        if clean and not (path.parent / clean).resolve().exists(): bad_links.append(f"{path.relative_to(ROOT)} -> {link}")
check(not bad_links, "relative Markdown links" + (": " + ", ".join(bad_links) if bad_links else ""))

release = ROOT / "release" / "V26.2.2"
for archive in sorted(release.glob("*.zip")) if release.exists() else []:
    try:
        with zipfile.ZipFile(archive) as zf:
            names = zf.namelist()
            check(not any(n.startswith((".git/","archive/")) or n.endswith((".tmp",".bak",".orig")) for n in names), f"{archive.name} clean entries")
            if archive.name.endswith("-SD.zip"):
                check(names == ["SCRIPTS/GIB2A/main.lua"], f"{archive.name} exact structure")
            elif archive.name.endswith("-ETHOS-Suite.zip"):
                expected = {
                    "CHANGELOG.md", "INSTALLATION.md", "README.md",
                    "ethos_lua_manifest.json", "main.lua",
                }
                check(set(names) == expected and len(names) == len(expected), f"{archive.name} exact structure")
                manifest = json.loads(zf.read("ethos_lua_manifest.json").decode("utf-8"))
                check(
                    manifest.get("manifestVersion") == 1
                    and manifest.get("version") == EXPECTED_VERSION
                    and manifest.get("folder") == "GIB2A"
                    and manifest.get("files") == [
                        "main.lua", "README.md", "CHANGELOG.md", "INSTALLATION.md"
                    ],
                    f"{archive.name} manifest coherence",
                )
            mains = [n for n in names if n == "main.lua" or n.endswith("/main.lua")]
            check(len(mains) == 1, f"{archive.name} has one main.lua")
            if mains:
                payload = zf.read(mains[0])
                check(hashlib.sha256(payload).hexdigest().upper() == EXPECTED_HASH, f"{archive.name} main.lua hash")
                check(len(payload) == EXPECTED_SIZE and b"\r" not in payload, f"{archive.name} main.lua format")
    except zipfile.BadZipFile:
        check(False, f"{archive.name} valid ZIP")

if errors:
    print(f"Result: FAIL ({len(errors)} error(s))")
    sys.exit(1)
print("Result: PASS")
