# GIBA — Xicoy ProHub Turbine Telemetry Widget (ETHOS) — V1.1

## Download

[📦 Download ZIP](https://github.com/GIB2A/ETHOS-LUA-XICOY/releases/latest/download/GIB2A-Xicoy-ProHub-Widget-V1.1.zip)

> Latest packaged version ready to copy to the SD card.

Repository: `https://github.com/GIB2A/ETHOS-LUA-XICOY`

**Widget name shown on the radio (ETHOS):** `GIBA - Xicoy ProHUb - V1.1  Corsica fly dream`  
**Widget key (internal):** `GIB2A`  
**Version:** `1.1.0` (see `VERSION`)

An **ETHOS Lua widget** for **FrSky ETHOS radios** that displays **Xicoy ProHub** turbine telemetry with a pilot-focused dashboard and a full configuration menu.

The widget also supports multiple ECU status decoding presets directly in the configuration menu, including **Xicoy**, **JetCat**, **KingTech**, and **Swiwin**.

---

## Highlights

- Dashboard (core)
  - **RPM** (red zone above 100% up to 110%)
  - **EGT** (Temp1) (red zone above 700°C)
  - **Pump** (ADC4)
  - **Fuel**
- **Real-value oriented display**
  - values shown as real numbers, not generic percent labels
- **ECU Status** decoding with selectable ECU type
  - Xicoy / JetCat / KingTech / Swiwin
- **Setup Mode**
  - **Basic**: core dashboard only
  - **Expert**: adds optional ProHub Extended / Maximum sensors
- Optional **Extended / Maximum** sensors in Expert mode
  - Ambient Temp, Pressure, Altitude, Fuel Flow, Serial Number, Battery Used, Engine Time, Pump Amperage
- **Fuel alarms**
  - configurable **Alert %** and **Critical %** thresholds
  - optional audio file per threshold
  - haptic feedback on critical threshold crossing
- Optional left-column information
  - ECU V (ADC3), Rx Batt, RSSI 2.4G, RSSI 900M, DIY1 / DIY2 / DIY3 with unit suffix when available
- **Themes**
  - Standard / High contrast / Amber

---

## Compatibility

- **ETHOS**: widget for FrSky ETHOS radios
- **Radios**: ETHOS-compatible FrSky radios with widget support
- **Telemetry**: Xicoy ProHub configured in **FrSky** mode (S.Port)
- **ECU status presets**: Xicoy / JetCat / KingTech / Swiwin

---

## Hardware / Telemetry chain

Typical setup:

`Turbine ECU → Xicoy ProHub → Receiver S.Port (Smart Port) → ETHOS Radio`

**Important**: on some FrSky receivers you must explicitly assign a pin as **Smart Port (S.Port)** in the receiver options.

---

## Installation

### Step 1 — Download
1. Open the repository page.
2. Click **Code → Download ZIP** or use the download link above.
3. Extract the ZIP.

### Step 2 — Copy to the SD card
Copy the files so you end up with:

`SCRIPTS/GIB2A/main.lua`

**Do not** create extra nested folders.  
Wrong example: `SCRIPTS/GIB2A/GIB2A/main.lua`

### Step 3 — Discover sensors

#### A) Standard discovery
1. Power the model (**ECU + ProHub + receiver**).
2. On the radio, go to **Telemetry → Discover sensors**.
3. Wait until sensors appear and values stabilize.

#### B) If some sensors do not appear
Some setups expose certain values through DIY sensor discovery.

1. Go to **Telemetry → DIY Sensor → Auto Detect**.
2. Detect one missing sensor.
3. Repeat if needed for the others.

### Step 4 — Add the widget
Go to:

**Model → Display → Widgets → Add widget**

Select:

`GIBA - Xicoy ProHUb - V1.1  Corsica fly dream`

Then open widget settings and assign the discovered sensors.

---

## ProHub setup (FrSky)

### 1) Select FrSky telemetry mode on the ProHub
On the ProHub:
1. Enter telemetry setup.
2. Select **FrSky**.
3. Choose **Basic**, **Extended**, or **Maximum**.
4. Save and power-cycle receiver / ProHub if required.

Notes:
- **Basic** uses standard FrSky addresses.
- **Extended / Maximum** exposes more measurements.
- Higher telemetry volume can reduce refresh rate.

### 2) Wiring
- Connect a servo patch cable from a ProHub telemetry port to the receiver **S.Port**.

### 3) Quick validation
- The ProHub telemetry LED should indicate a valid link.
- Then run sensor discovery on ETHOS.

---

## Widget configuration

Open the widget settings and assign the telemetry sources discovered by ETHOS.

### Setup Mode
- **Basic**: core dashboard only
- **Expert**: enables optional fields and Extended / Maximum telemetry display

### ECU Type
Select the ECU status decoding table:
- Xicoy
- JetCat
- KingTech
- Swiwin

### Core fields
- **STATUS ECU Sensor**
- **RPM Sensor** + **RPM Max (100%)**
- **Temp1 Sensor (EGT)** + **EGT Max (100%)**
- **ADC3 Sensor (ECU V)**
- **ADC4 Sensor (Pump)** + **Pump Max (100%)**
- **Fuel Sensor (Real)** + **Fuel Max (Full)**

### Fuel alarms
- **Fuel Alert (%)**
- **Fuel Critical Alert (%)**
- **Fuel Alert Sound**
- **Fuel Critical Sound**

### Expert-only optional ProHub sensors
- **Ambient Temp (°C)**
- **Pressure (mBar)**
- **Altitude (m)**
- **Fuel Flow (ml/min)**
- **Serial Number**
- **Battery Used (mAh)**
- **Engine Time (s)**
- **Pump Amperage (0.1A)**

### Extra optional sources
- **DIY1 Sensor**
- **DIY2 Sensor**
- **DIY3 Sensor**
- **RxBatt Sensor**
- **RSSI Sensor 1 (2.4G)**
- **RSSI Sensor 2 (900M)**
- **Chrono Source**

### Theme
- Standard
- High contrast
- Amber

---

## Display behavior

- **RPM** is displayed as a real value, with alert band above 100%.
- **EGT** is displayed as a real value, with red zone starting above 700°C.
- **Pump** is displayed as a real value.
- **Fuel** is displayed numerically and monitored for alert thresholds.
- **Status ECU** is decoded according to the selected ECU type.

---

## ProHub FrSky measurement reference

### Basic
- EGT: `0x400`
- RPM: `0x500`
- Throttle %: `0xA20`
- Battery voltage: `0x900`
- Pump RPM: `0x910`
- Fuel remaining (%): `0xA10`
- Status: `0x410`

### Extended / Maximum
- EGT: `0x4400`
- RPM: `0x4401`
- Ambient Temp: `0x4407`
- Pressure: `0x4408`
- Altitude: `0x4409`
- Fuel Flow: `0x440A`
- Serial Number: `0x440B`
- Battery Used: `0x440C`
- Engine Time: `0x440D`
- Pump Amperage: `0x440E`

---

## Troubleshooting

### Widget does not appear in the widget list
- Confirm the SD path is exactly: `SCRIPTS/GIB2A/main.lua`
- Remove accidental nested folders.
- Reboot the radio.

### No telemetry values / No data
- Confirm ProHub is set to **FrSky** telemetry.
- Confirm ProHub → receiver **S.Port** wiring.
- Confirm sensor discovery has been run.
- Check ProHub telemetry LED status.

### Only some values are present
- Try **DIY Auto Detect**.
- Verify each widget source selection matches the expected telemetry field.
- If using Extended / Maximum data, set **Setup Mode = Expert**.

---

## Safety

This widget is software only. Safe turbine operation remains your responsibility.

Key reminders:
- A turbine engine is **not a toy**.
- Keep a suitable fire extinguisher nearby.
- Operate in open air.
- Keep spectators, children, and animals at a safe distance.
- Protect eyes and ears during start.

---

## Design principles

- ETHOS-friendly structure
  - `wakeup()` for telemetry and logic
  - `paint()` for drawing
  - `configure()` for setup UX
- Stable and predictable behavior
- Minimal setup burden for the pilot

---

## Debug checklist

When a user reports **no data**:
1. Confirm SD path: `SCRIPTS/GIB2A/main.lua`
2. Confirm ProHub is in FrSky mode and receiver S.Port is configured
3. Confirm ETHOS telemetry discovery was run
4. Confirm widget sources are assigned
5. Ask for discovered sensor list and screenshots

---

## Support / Feedback

Please open a GitHub Issue and include:
- Radio model + ETHOS version
- ProHub firmware / version if known
- Selected telemetry mode: Basic / Extended / Maximum
- Selected ECU type: Xicoy / JetCat / KingTech / Swiwin
- List of discovered sensors
- Screenshots of telemetry page and widget settings

---

## License / Disclaimer

MIT — see `LICENSE`  
See `DISCLAIMER.md` for warranty / liability limitations.
