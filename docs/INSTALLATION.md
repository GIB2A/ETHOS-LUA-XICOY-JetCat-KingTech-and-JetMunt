# Installation

Uninstall or remove any previous GIB2A widget version before installing
V26.3.2. Then follow either the manual SD or ETHOS Suite procedure below.

## Manual SD installation

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.3.2-SD.zip`.
2. Verify it against `SHA256SUMS.txt`.
3. Extract it at the SD-card root.
4. Confirm the exact paths `SCRIPTS/GIB2A/main.lua` and
   `SCRIPTS/GIB2A/gib2a_logo_ethos_180.png`.
5. Reboot the radio and add the GIB2A widget.
6. Discover telemetry and configure sources.

The uppercase `SCRIPTS` path is preserved from the validated V1.1 manual package.
Do not add an extra enclosing directory.

## ETHOS Suite

1. Download `GIB2A-Xicoy-ProHub-Widget-V26.3.2-ETHOS-Suite.zip`.
2. In ETHOS Suite, choose `Lua Library` -> `Install from local .zip`.
3. Select the archive without extracting it.
4. Let ETHOS Suite install the `GIB2A` folder, then verify the widget on the radio.

The manifest schema, folder key and root-level package layout are inherited from
the official V1.1 ETHOS Suite release. The V26.3.2 package installs `main.lua`
and `gib2a_logo_ethos_180.png` together in the `GIB2A` folder.

Verify the archive with the SHA-256 published in `SHA256SUMS.txt` before
installation. The checksum is intentionally kept outside this document because
`INSTALLATION.md` is itself included in the ZIP; embedding the ZIP checksum here
would make the archive checksum self-referential.
