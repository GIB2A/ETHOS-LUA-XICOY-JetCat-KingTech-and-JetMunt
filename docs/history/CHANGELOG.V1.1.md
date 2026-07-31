# Changelog

All notable changes to this project will be documented in this file.

The format is based on *Keep a Changelog* and this project adheres to *Semantic Versioning*.

## [Unreleased]

## [1.1.0] - 2026-01-19
### Added
- Multi-ECU **STATUS** decoding: **Xicoy**, **JetCat**, **KingTech**, **Swiwin** (selectable in the configuration menu).
- **Themes**: Standard / High contrast / Amber.
- **Fuel alarms** with configurable thresholds (Alert / Critical), optional audio files, and haptic feedback on critical threshold crossing.
- Optional sources displayed in the left column: **RSSI 2.4G**, **RSSI 900M**, **Rx Batt**, **ECU V**, plus **DIY1/DIY2/DIY3** with automatic unit suffix.
- **Expert** mode optional ProHub sensors: Ambient Temp, Pressure, Altitude, Fuel Flow, Serial Number, Battery Used, Engine Time, Pump Amperage.

### Changed
- Dashboard now emphasizes **real values** (RPM / EGT / Pump / Fuel) with clear red zones (EGT > 700°C, RPM > 100% up to 110%).
- Configuration menu labels and behavior aligned with ETHOS choice fields (rebuilds menu when switching Basic/Expert).

### Fixed
- More robust Source reading and safer gauge geometry (clamping to avoid drawing outside the widget area).

## [1.0.0-beta] - 2025-12-12
### Added
- First public beta release of the **GIB2A** widget (ETHOS 1.7)
- Configuration menu
- Core dashboard: RPM / EGT / Pump / Fuel
