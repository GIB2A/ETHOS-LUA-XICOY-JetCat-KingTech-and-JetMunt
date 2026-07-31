# AGENTS.md

1. `src/GIB2A/main.lua` is a validated functional reference.
2. Before changing `main.lua`, create an exact timestamped archive.
3. Calculate SHA-256 before and after any intervention.
4. Never change the validated version without explicit authorization.
5. Keep `storage.read()` and `storage.write()` keys in exactly the same order.
6. Keep the same number of read and write keys.
7. Never reintroduce PERF DEBUG into the public version.
8. Build archives only with `tools/build_release.py`.
9. Verify the extracted `main.lua` hash from every ZIP.
10. Never push or publish without explicit authorization.
11. Never track `archive/` or `release/`.
12. Never invent ECU compatibility.
13. Never invent an ETHOS Suite manifest.
14. Never automatically reformat the validated Lua file.
15. Report every anomaly before correcting it.
