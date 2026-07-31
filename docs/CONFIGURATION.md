# Configuration

1. Discover telemetry sensors in ETHOS.
2. Add the GIB2A widget and select the ECU brand.
3. Select Xicoy Basic (0), Extended (1), Maximum (2), or the relevant brand mode.
4. Use Xicoy AppID auto-bind or Enjet DTA auto-bind when applicable.
5. For Linton, KingTech, Swiwin and JetCat, assign sources manually.
6. Verify RPM, EGT, Fuel, Pump, ECU Status, radio THR, ECU THR and Heli/TP RPM.

ECU mapping is Xicoy=0, JetCat=1, KingTech=2, Swiwin=3, Linton=4, Enjet=5.
The menu order differs, but maps to these internal values.

Radio THR is converted from ETHOS `-1024..+1024` to `0..100%`. Xicoy Fuel Level
After Restart can reset the displayed starting level. Default configurable fuel
thresholds are 35% and 15%; fixed color/sound callouts are 50% and 25%.

After an ECU or simulator restart, rerun ETHOS telemetry discovery if sources do
not recover. Always validate values on the ground before flight.
