# GIB2A Turbine Telemetry Widget — Installation

Uninstall or remove any previous GIB2A widget version before installing
V26.3.6. Then follow either the manual SD or ETHOS Suite procedure below.

## Manual SD installation

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.3.6-SD.zip`.
2. Verify its SHA-256 against the versioned
   [V26.3.6 checksum file](../checksums/GIB2A-V26.3.6.sha256).
3. Extract it at the SD-card root.
4. Confirm the exact paths `SCRIPTS/GIB2A/main.lua` and
   `SCRIPTS/GIB2A/gib2a_logo_ethos_180.png`.
5. Reboot the radio and add the GIB2A widget.
6. Discover telemetry and configure sources.

The uppercase `SCRIPTS` path is preserved from the validated V1.1 manual package.
Do not add an extra enclosing directory.

## ETHOS Suite

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.3.6-ETHOS-Suite.zip`.
2. Verify its SHA-256 against the versioned
   [V26.3.6 checksum file](../checksums/GIB2A-V26.3.6.sha256).
3. Open ETHOS Suite.
4. Choose `Lua Library` -> `Install from local .zip`.
5. Select the archive without extracting it.
6. Let ETHOS Suite install the `GIB2A` folder.
7. Verify the widget on the radio.

The manifest schema, folder key and root-level package layout are inherited from
the official V1.1 ETHOS Suite release. The V26.3.6 package installs `main.lua`
and `gib2a_logo_ethos_180.png` together in the `GIB2A` folder.

The versioned checksum file records the hashes of the two immutable GitHub
Release assets and the validated `main.lua` baseline.

## Custom / DIY telemetry sensors in ETHOS 26.x

Depending on the ECU and telemetry protocol, some fields are not created as
standard FrSky sensors. In that case, discover or create only the required
fields under ETHOS `Custom sensors / DIY`, using the IDs documented by the ECU
manufacturer or by this project. This procedure is not required for every ECU
or every GIB2A field. GIB2A Auto Bind remains the preferred assignment method
when it is available for the selected ECU; otherwise, select the sensor
manually in the widget configuration.

### Example — JetCat Engine 1 / Remaining Fuel Volume

1. Open the ETHOS telemetry sensor configuration.
2. Create or select a DIY sensor.
3. Set the sensor name to `EngRestFuel1`.
4. Set Physical ID to `0x1B`.
5. Set Application ID / Data ID to `0x5005`.
6. Set the unit to `ml`.
7. Return to the GIB2A Turbine Telemetry Widget configuration.
8. Use JetCat Engine 1 Auto Bind when supported, or manually select the sensor
   if necessary.

For JetCat, the trailing `1` in `EngRestFuel1` identifies Engine / ECU 1. GIB2A
uses this JetCat naming convention for the supported Engine 1 Auto Bind sensor
set, but `EngRestFuel1` is not one of the 11 fields auto-bound in V26.3.6; select
it manually when required. Do not apply this naming convention to other ECU
brands unless their GIB2A documentation explicitly requires it.

Source: `docs/references/GIB2A_JetCat_FrSky_Sensor_ID_Reference.pdf` (ECU 1
Physical ID `0x1B`; Remaining Fuel Volume Data ID `0x5005`; unit `ml`) and the
JetCat Engine 1 sensor naming implemented in this release.
