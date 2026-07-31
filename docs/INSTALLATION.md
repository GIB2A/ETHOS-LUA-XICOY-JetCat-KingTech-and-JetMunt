# Installation

## Manual SD installation

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.2.2-SD.zip`.
2. Verify it against `SHA256SUMS.txt`.
3. Extract it at the SD-card root.
4. Confirm the exact path `SCRIPTS/GIB2A/main.lua`.
5. Reboot the radio and add the GIB2A widget.
6. Discover telemetry and configure sources.

The uppercase `SCRIPTS` path is preserved from the validated V1.1 manual package.
Do not add an extra enclosing directory.

## ETHOS Suite

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.2.2-ETHOS-Suite.zip`.
2. In ETHOS Suite, open the Lua Library and choose installation from a local ZIP.
3. Select the archive without extracting it.
4. Let ETHOS Suite install the `GIB2A` folder, then verify the widget on the radio.

The manifest schema, folder key and root-level package layout are inherited from
the official V1.1 ETHOS Suite release. The V26.2.2 package updates only the
version, release notes and validated release files required by that schema.
