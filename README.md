# GIB2A FrSky ETHOS Turbine Telemetry

GIB2A V26.2.2 is a telemetry-only Lua widget for FrSky ETHOS radios. It displays
turbine and ECU telemetry; it never starts, stops, restarts or controls a turbine.

[Lire en français](README_FR.md)

![GIB2A widget preview](assets/gib2a-widget-preview.jpg)

## Features

- Pilot-readable RPM, EGT, fuel, pump and ECU status dashboard
- Xicoy Basic, Extended and Maximum modes with matching AppID auto-bind
- Enjet DTA auto-bind
- Manual source assignment for every supported ECU
- Radio THR conversion from ETHOS `-1024..+1024` to `0..100%`
- ECU THR and Heli/TP RPM sources
- Xicoy Fuel Level After Restart
- Standard, high-contrast and amber themes
- Fixed fuel level callouts at 50% and 25%
- Configurable fuel alerts (defaults: 35% alert, 15% critical)
- Configurable FlameOut and Restart status alarms


## Compatibility

| Brand | ECU status | Manual assignment | Auto-bind | Specific modes |
|---|---|---|---|---|
| Xicoy | Yes | Yes | Yes | Basic, Extended, Maximum |
| Enjet | Yes | Yes | Yes | DTA |
| Linton | Yes | Yes | No | Manual sources |
| KingTech | Yes | Yes | No | Manual sources |
| Swiwin | Yes | Yes | No | Manual sources |
| JetCat | Yes | Yes | No | Manual sources |

GIB2A is an independent project and is not affiliated with the listed
manufacturers. No manufacturer has officially certified this software unless
explicitly stated.
JetMunt compatibility is not claimed because it has not been demonstrated here.

## Installation

For manual installation, extract the SD package so the radio contains exactly
`SCRIPTS/GIB2A/main.lua`, then reboot the radio and add the `GIB2A` widget.
For ETHOS Suite, use the dedicated Suite archive whose manifest schema and
root-level file layout are inherited from the official V1.1 package. See
[Installation](docs/INSTALLATION.md).

## Configuration and telemetry

Select the ECU brand and telemetry mode, discover sensors in ETHOS, use the
brand-specific auto-bind where available, then verify every assigned source.
Xicoy supports Basic, Extended and Maximum auto-bind. Enjet has a separate DTA
auto-bind. Linton, KingTech, Swiwin and JetCat primarily use manual assignment.
After restarting an ECU or simulator, restart ETHOS telemetry discovery if values
do not return. See [Configuration](docs/CONFIGURATION.md).

## Alarms and safety

Fuel display callouts occur at 50% (yellow) and 25% (red); configurable alerts
default to 35% and 15%. FlameOut and Restart alarms detect valid ECU status
transitions after a running state. Restart detection does not restart the engine.
Alarms do not replace pilot monitoring, and manufacturer procedures always take
priority. See the [Disclaimer](docs/DISCLAIMER.md).

## Documentation

- [Project repository](https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry)
- [Releases](https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry/releases)
- [V26.2.2 release](https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry/releases/tag/v26.2.2)
- [Compatibility](docs/COMPATIBILITY.md)
- [Configuration](docs/CONFIGURATION.md)
- [Installation](docs/INSTALLATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [V26.2.2 release notes](docs/release-notes/V26.2.2.md)
- [Contributing](docs/CONTRIBUTING.md)

Report problems through [GitHub Issues](https://github.com/GIB2A/GIB2A-FrSky-ETHOS-Turbine-Telemetry/issues).
