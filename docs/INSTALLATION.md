# Installation

Uninstall or remove any previous GIB2A widget version before installing
V26.3.5. Then follow either the manual SD or ETHOS Suite procedure below.

## Manual SD installation

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.3.5-SD.zip`.
2. Verify its SHA-256 against the versioned
   [V26.3.5 checksum file](../checksums/GIB2A-V26.3.5.sha256).
3. Extract it at the SD-card root.
4. Confirm the exact paths `SCRIPTS/GIB2A/main.lua` and
   `SCRIPTS/GIB2A/gib2a_logo_ethos_180.png`.
5. Reboot the radio and add the GIB2A widget.
6. Discover telemetry and configure sources.

The uppercase `SCRIPTS` path is preserved from the validated V1.1 manual package.
Do not add an extra enclosing directory.

## ETHOS Suite

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.3.5-ETHOS-Suite.zip`.
2. Verify its SHA-256 against the versioned
   [V26.3.5 checksum file](../checksums/GIB2A-V26.3.5.sha256).
3. Open ETHOS Suite.
4. Choose `Lua Library` -> `Install from local .zip`.
5. Select the archive without extracting it.
6. Let ETHOS Suite install the `GIB2A` folder.
7. Verify the widget on the radio.

The manifest schema, folder key and root-level package layout are inherited from
the official V1.1 ETHOS Suite release. The V26.3.5 package installs `main.lua`
and `gib2a_logo_ethos_180.png` together in the `GIB2A` folder.

The versioned checksum file records the hashes of the two immutable GitHub
Release assets and the validated `main.lua` baseline.
