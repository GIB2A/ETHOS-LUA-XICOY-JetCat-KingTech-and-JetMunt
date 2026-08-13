# Releasing

Publication is manual and must be explicitly authorized. From a reviewed branch:

```powershell
git remote set-url origin "https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry.git"
python tools/validate_release.py
python tools/build_release.py
git diff --check
git add .
git commit -m "Release GIB2A V26.3.2"
git push origin main
git tag -a v26.3.2 -m "GIB2A V26.3.2"
git push origin v26.3.2
```

After review, create a GitHub Release titled `GIB2A V26.3.2`, paste the prepared release notes,
and attach both validated ZIPs plus `SHA256SUMS.txt`. Do not run these publication
commands without authorization. The ETHOS Suite package uses the validated V1.1
manifest schema stored in `packaging/ethos_lua_manifest.json`.

## Repository presentation

Description:

> FrSky ETHOS Lua turbine telemetry widget for Xicoy ProHub with multi-ECU status support.

Topics: `frsky`, `ethos`, `lua`, `telemetry`, `rc-jet`, `turbine`, `xicoy`,
`jetcat`, `kingtech`, `swiwin`, `enjet`, `linton`.
