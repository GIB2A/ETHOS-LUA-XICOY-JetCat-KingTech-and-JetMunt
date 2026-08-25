# Changelog

## [26.3.4] - 2026-08-25

### Changed
- strengthened recovery of invalid, renamed or temporarily unavailable telemetry sources
- preserved voluntary Auto Bind behavior when changing Xicoy telemetry mode
- prepared the validated ETHOS 26.1 radio baseline for public distribution

### Fixed
- corrected the JetCat PUMP gauge with a configurable 1.7 V default scale and 110% reserve zone
- persisted the JetCat PUMP maximum setting

### Validation
- completed 39 ETHOS 26.1 radio tests with 39 PASS and 0 FAIL

## [26.3.2] - 2026-08-13

### Added
- JetCat Engine 1 auto-bind for 11 telemetry sensors
- JetCat shutdown-condition decoding, including legacy negative formats
- JetCat FlameOut and Auto-Restart alerts

### Changed
- aligned JetCat EngState decoding with JetCat ETHOS v0.9.24
- isolated ECU-specific telemetry sources when changing turbine manufacturer
- refactored persistence and wakeup processing with static tables
- reduced repetitive Lua code while keeping telemetry reads outside `paint()`
- improved the dashboard and sensor-information readability

### Unchanged
- Xicoy ProHub and EnJet DTA auto-bind support
- manual source assignment for Linton/KAVAN, KingTech and Swiwin
- Xicoy FlameOut and Restart alerts

## [26.3.1] - 2026-08-11

### Fixed
- corrected ETHOS system-source handling for receiver voltage
- corrected RSSI 2.4 GHz and 900 MHz source handling
- displayed RSSI values with an explicit `%` unit

### Unchanged
- turbine telemetry AppID mappings
- Xicoy and EnJet auto-bind logic

## [26.3.0] - 2026-08-11

### Added
- external GIB2A PNG logo distributed with the widget
- left and right telemetry-information panels
- adaptive panel typography based on visible sensors

### Changed
- redesigned pilot-focused main dashboard
- centralized ECU status and flight timer
- redesigned RPM, EGT, pump and fuel rendering

## [26.2.2] - 2026-07-31

### Added
- support Enjet
- support Linton
- modes Xicoy Basic, Extended et Maximum
- auto-bind Xicoy par AppID
- auto-bind Enjet DTA
- capteur ECU Throttle
- capteur Heli ou TP RPM
- Fuel Level After Restart pour Xicoy
- callouts fixes carburant 50 % et 25 %
- alarmes configurables FlameOut et Restart
- source radio THR
- nouveaux champs de persistance

### Changed
- Fuel Alert par défaut à 35 %
- Fuel Critical par défaut à 15 %
- lecture directe des sources en fonctionnement normal
- récupération protégée après erreur
- récupération limitée à une fois par seconde et par source
- mise en cache des sources récupérées
- invalidation LCD regroupée
- conversion THR ETHOS de -1024..+1024 vers 0..100 %
- gestion de la pompe Xicoy

### Fixed
- zone EGT rouge à partir de 700 °C
- cohérence des alarmes carburant
- conservation de FlameOut
- stabilité de lecture des sources
- synchronisation des 43 clés de persistance

### Removed
- suppression de PERF DEBUG de la version publique

## [1.1.0] - 2026-01-19

Historical release; see [V1.1 notes](docs/release-notes/V1.1.md).
