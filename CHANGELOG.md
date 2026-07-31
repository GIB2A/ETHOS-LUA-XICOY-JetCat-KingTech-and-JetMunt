# Changelog

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
