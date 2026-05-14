# GIB2A — Turbine Telemetry Widget for FrSky ETHOS

**GIB2A** is an ETHOS Lua widget dedicated to RC turbine telemetry display on FrSky ETHOS radios.

This release is focused on **Xicoy ProHub telemetry in FrSky S.Port mode**, with a pilot-oriented dashboard for turbine operation and a clean configuration menu directly on the radio.

The project is designed as a stable foundation for future multi-brand turbine support while remaining **100% ETHOS-friendly**: the script reads telemetry sources discovered by ETHOS and does not perform direct low-level S.Port decoding.

---

<p align="center">
  <img src="assets/gib2a-widget-preview.jpg" alt="GIB2A ETHOS turbine telemetry widget preview" width="900">
</p>

---

## Download

Download the latest packaged version from the GitHub releases page:

[📦 GitHub Releases](https://github.com/GIB2A/ETHOS-LUA-XICOY-JetCat-KingTech-and-JetMunt/releases)

Use the ZIP file available in the release **Assets** section:

```text
GIB2A-Xicoy-ProHub-Widget-V1.1-ETHOS-Suite.zip
```

Do **not** use the automatic GitHub **Source code** ZIP for installation.

The ETHOS Suite compatible ZIP contains an `ethos_lua_manifest.json` file at the root of the archive.

---

## Current version

| Item | Value |
|---|---|
| Project | GIB2A Turbine Telemetry Widget |
| ETHOS widget key | `GIB2A` |
| Current release | `V1.1` |
| Main script | `main.lua` |
| Target platform | FrSky ETHOS |
| Main telemetry target | Xicoy ProHub in FrSky mode |
| Installation package | `GIB2A-Xicoy-ProHub-Widget-V1.1-ETHOS-Suite.zip` |

---

## Main features

- Turbine telemetry dashboard for FrSky ETHOS radios
- Pilot-focused display of essential turbine values:
  - RPM
  - EGT / Temp1
  - Pump value
  - Fuel remaining
  - ECU status
  - Receiver battery
  - RSSI
- Configurable sensor assignment from the ETHOS widget settings page
- ECU status decoding presets:
  - Xicoy
  - JetCat
  - KingTech
  - Swiwin
- Basic and Expert setup modes
- Optional ProHub Extended / Maximum telemetry fields in Expert mode:
  - Ambient temperature
  - Pressure
  - Altitude
  - Fuel flow
  - Serial number
  - Battery used
  - Engine time
  - Pump amperage
- Fuel alert and critical alarm thresholds
- Optional audio file selection for fuel alerts
- Haptic feedback on critical fuel alert
- Theme options for cockpit readability

---

## Compatibility

### Radios

The widget is intended for FrSky radios running ETHOS with Lua widget support, including Tandem and other ETHOS-compatible radios.

### ETHOS

The script follows the public ETHOS Lua widget architecture:

- `wakeup()` for telemetry and logic
- `paint()` for drawing
- `configure()` for the setup menu
- `read()` / `write()` for widget persistence

### Telemetry chain

Typical setup:

```text
Turbine ECU → Xicoy ProHub → Receiver S.Port → ETHOS Radio → GIB2A Widget
```

Important: on some FrSky receivers, the telemetry pin must be configured explicitly as **S.Port / Smart Port** in the receiver options.

---

## Installation with ETHOS Suite

This is the recommended and supported installation method.

1. Download the release ZIP from the GitHub release **Assets** section:

```text
GIB2A-Xicoy-ProHub-Widget-V1.1-ETHOS-Suite.zip
```

2. Open **ETHOS Suite**.
3. Go to **Lua Library**.
4. Choose **Install from local .zip**.
5. Select:

```text
GIB2A-Xicoy-ProHub-Widget-V1.1-ETHOS-Suite.zip
```

6. ETHOS Suite installs the widget according to the included `ethos_lua_manifest.json`.

The widget is installed under:

```text
RADIO:/scripts/GIB2A/
```

---

## ProHub setup for FrSky telemetry

On the Xicoy ProHub:

1. Enter the telemetry setup menu.
2. Select **FrSky**.
3. Choose the desired telemetry mode:
   - Basic
   - Extended
   - Maximum
4. Save the configuration.
5. Power-cycle the receiver / ProHub if required.
6. Run sensor discovery on ETHOS.

Notes:

- **Basic** uses standard FrSky sensor addresses.
- **Extended / Maximum** exposes more telemetry values.
- Higher telemetry volume can reduce refresh rate.

---

## ETHOS sensor discovery

### Standard discovery

1. Power the model with ECU, ProHub and receiver connected.
2. On the radio, open the telemetry page.
3. Start **Discover new sensors**.
4. Wait until the sensors appear and values stabilize.
5. Stop discovery.

### DIY sensor discovery

On some ETHOS / receiver / ProHub combinations, not all values are discovered automatically.

If a value is missing:

1. Go to **Telemetry → DIY Sensor → Auto Detect**.
2. Detect the missing sensor.
3. Repeat for the other missing fields if needed.
4. Assign the detected sensors in the GIB2A widget settings.

---

## ProHub FrSky telemetry reference

### Basic mode

| Measure | FrSky AppID |
|---|---:|
| EGT / Exhaust temperature | `0x0400` |
| ECU status | `0x0410` |
| Turbine RPM | `0x0500` |
| ECU battery voltage | `0x0900` |
| Pump value | `0x0910` |
| Fuel remaining | `0x0A10` |
| Throttle | `0x0A20` |
| Heli / turboprop RPM | `0x0A30` |

### Extended / Maximum mode

| Measure | FrSky AppID |
|---|---:|
| EGT / Exhaust temperature | `0x4400` |
| Turbine RPM | `0x4401` |
| Throttle | `0x4402` |
| ECU battery voltage | `0x4403` |
| Pump value | `0x4404` |
| Fuel remaining | `0x4405` |
| ECU status | `0x4406` |
| Ambient temperature | `0x4407` |
| Pressure | `0x4408` |
| Altitude | `0x4409` |
| Fuel flow | `0x440A` |
| Serial number | `0x440B` |
| Battery used | `0x440C` |
| Engine time | `0x440D` |
| Pump amperage | `0x440E` |
| Heli / turboprop RPM | `0x4414` |

---

## Widget configuration

Add the widget from:

```text
Model → Display → Widgets → Add widget
```

Then open the widget settings and assign the telemetry sources discovered by ETHOS.

### Core fields

- STATUS ECU Sensor
- RPM Sensor
- RPM Max
- Temp1 / EGT Sensor
- EGT Max
- ECU voltage sensor
- Pump sensor
- Pump Max
- Fuel sensor
- Fuel Max

### Fuel alarms

- Fuel Alert (%)
- Fuel Critical Alert (%)
- Fuel Alert Sound
- Fuel Critical Sound

### Expert mode fields

- Ambient temperature
- Pressure
- Altitude
- Fuel flow
- Serial number
- Battery used
- Engine time
- Pump amperage

### Optional extra sources

- DIY1 / DIY2 / DIY3
- Rx battery
- RSSI 2.4G
- RSSI 900M
- Chrono source

---

## Troubleshooting

### The widget does not appear

Check:

- The installed package is the release asset named `GIB2A-Xicoy-ProHub-Widget-V1.1-ETHOS-Suite.zip`.
- The package was installed through **ETHOS Suite → Lua Library → Install from local .zip**.
- ETHOS Suite installed the widget under `RADIO:/scripts/GIB2A/`.
- The radio has been rebooted after installation if needed.

### No telemetry values are displayed

Check:

- ProHub is configured in **FrSky** telemetry mode.
- The ProHub telemetry port is connected to the receiver S.Port.
- The receiver pin is correctly configured as S.Port if required.
- ETHOS sensor discovery has been run.
- The widget sources are assigned in the widget settings.

### Only some values appear

Try:

- Run ETHOS sensor discovery again.
- Use **DIY Sensor → Auto Detect** for missing values.
- Use **Expert** mode when working with ProHub Extended / Maximum telemetry.
- Verify that each widget field is assigned to the correct telemetry source.

---

## Safety notice

This widget is a display and assistance tool only. It does not replace safe turbine operation, ECU procedures, manufacturer instructions, or pilot responsibility.

Basic reminders:

- A turbine engine is not a toy.
- Always follow the turbine manufacturer manual.
- Keep a suitable fire extinguisher nearby.
- Operate only in open air.
- Keep spectators, children and animals at a safe distance.
- Protect eyes and ears during startup and operation.
- Never rely on a Lua widget as the only safety indicator.

---

## Design philosophy

GIB2A is built around a simple principle:

> clean ETHOS integration, readable cockpit telemetry, predictable behavior, and no low-level workaround that would make the script dependent on one private firmware behavior.

The objective is to provide a robust turbine telemetry dashboard for ETHOS pilots and to keep the code understandable for ETHOS developers and advanced users.

---

## Feedback and support

Please open a GitHub Issue and include:

- Radio model
- ETHOS version
- Receiver type
- ProHub firmware version if known
- Selected ProHub telemetry mode: Basic / Extended / Maximum
- Selected ECU type in the widget
- List of discovered telemetry sensors
- Screenshots of the telemetry page and widget configuration

---

## Roadmap

Planned development direction:

- Improve layout behavior across ETHOS radio screen sizes
- Continue refining sensor assignment and display clarity
- Extend turbine telemetry support as manufacturer data becomes available
- Prepare future multi-brand turbine versions while keeping the same ETHOS-friendly architecture

---

## License and disclaimer

MIT — see `LICENSE` if provided in the repository.

This software is provided without warranty. Use it at your own risk. Safe model operation remains the responsibility of the pilot.
