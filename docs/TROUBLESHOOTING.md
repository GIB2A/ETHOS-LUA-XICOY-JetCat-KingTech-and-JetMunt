# Troubleshooting

- Widget missing: verify `SCRIPTS/GIB2A/main.lua`, folder case and reboot.
- No data: power ECU/receiver, rerun ETHOS sensor discovery, then reassign sources.
- Data lost after ECU/simulator restart: rerun discovery if automatic recovery
  does not restore values.
- Wrong value: verify ECU brand, telemetry mode and source assignment.
- Xicoy: verify Basic/Extended/Maximum matches ProHub.
- EnJet: use DTA auto-bind only for the intended DTA telemetry.
- JetCat: Engine 1 supports automatic binding. Verify the expected Engine 1 telemetry sensors are discovered before using auto-bind.
- Linton/KAVAN, KingTech and Swiwin: use explicit manual source assignment.
- Audio missing: select an accessible sound file for the active ETHOS voice.

Test alarms and values on the ground. Alarms do not replace pilot monitoring.
