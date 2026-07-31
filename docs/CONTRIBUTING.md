# Contributing

Keep changes small and reviewable. Do not modify `src/GIB2A/main.lua` without
explicit authorization and a verified timestamped archive. Preserve ETHOS
architecture, telemetry-only safety and the exact persistence key order.

Before a pull request run:

```powershell
python tools/validate_release.py
python tools/build_release.py
git diff --check
```

Include hashes before/after, ETHOS/radio test details and validation output.
