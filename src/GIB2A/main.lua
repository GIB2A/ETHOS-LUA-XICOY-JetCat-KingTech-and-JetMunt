-- GIB2A TURBINE Widget V26.3.1
-- Widget de télémétrie turbine multi-ECU pour ETHOS
-- Compatibilité Xicoy ProHub, Enjet, Linton, KingTech, Swiwin et JetCat
-- Modes Xicoy Basic, Extended et Maximum avec auto-bind des capteurs
-- Affichage RPM, EGT, pompe, carburant, statut ECU, THR radio et ECU THR
-- Alarmes carburant, callouts de niveau, FlameOut et Restart configurables
-- Zones d’alerte : EGT à partir de 700 °C et RPM au-delà de 100 % jusqu’à 110 %
-- Thèmes d’affichage et persistance complète des réglages

---@diagnostic disable: undefined-global

local audioPath = "/audio"
if system and system.getAudioVoice then
    local okAudioPath, detectedAudioPath = pcall(function()
        return system.getAudioVoice()
    end)
    if okAudioPath and detectedAudioPath then
        audioPath = detectedAudioPath
    end
end

local function playConfiguredAudio(fileName)
    if type(fileName) ~= "string"
        or fileName == ""
        or not system.playFile then
        return
    end

    local path = fileName

    if audioPath and string.sub(fileName, 1, 1) ~= "/" then
        path = audioPath .. "/" .. fileName
    end

    system.playFile(path)
end

local TELEMETRY_MODE_BASIC = 0
local TELEMETRY_MODE_EXTENDED = 1
local TELEMETRY_MODE_MAXIMUM = 2
local SETUP_MODE_SCHEMA = 2
local WIDGET_VERSION = "26.3.1"
local FUEL_YELLOW_THRESHOLD = 50
local FUEL_RED_THRESHOLD = 25
local GIB2A_LOGO_PATH = "gib2a_logo_ethos_180.png"
local GIB2A_LOGO_WIDTH = 130
local GIB2A_LOGO_HEIGHT = 57
local GIB2A_LOGO_COMPACT_WIDTH = 90
local GIB2A_LOGO_COMPACT_HEIGHT = 40
local gib2aLogo = nil

local function loadGib2aLogo()
    if gib2aLogo ~= nil or not lcd or not lcd.loadBitmap then
        return
    end

    local ok, bitmap = pcall(function()
        return lcd.loadBitmap(GIB2A_LOGO_PATH)
    end)
    if ok and bitmap then
        gib2aLogo = bitmap
    end
end

-- Xicoy pump telemetry uses a voltage-like value.
-- 12.6 telemetry units = 1260 pump RPM = 100%.
local XICOY_PUMP_RAW_MAX = 12.6

-------------------------------------------------------------
-- Création du widget
-------------------------------------------------------------

local function create(zone, options)
    return {
        zone    = zone,
        options = options,

        -- Chrono (timer ETHOS ou autre source temps)
        chronoSource   = nil, chronoValue   = nil,
        throttleSource = nil, throttleValue = nil,

        -- Capteurs Xicoy / ETHOS
        rpmSource      = nil, rpmValue      = nil,   -- RPM Sensor
        heliTpRpmSource = nil, heliTpRpmValue = nil, -- Heli/TP RPM optional second shaft RPM
        ecuThrottleSource = nil, ecuThrottleValue = nil,
        temp1Source    = nil, temp1Value    = nil,   -- Temp 1 (EGT)
        temp2Source    = nil, temp2Value    = nil,   -- Temp 2 (Status code)
        adc3Source     = nil, adc3Value     = nil,   -- ADC3 (ECU V)
        adc4Source     = nil, adc4Value     = nil,   -- ADC4 (Pump command / volt)

        fuelSource               = nil, fuelValue             = nil,   -- Fuel remaining (valeur réelle)
        fuelAlertPercent         = 35,                        -- Seuil alarme (% restant)
        fuelCriticalAlertPercent = 15,                        -- Seuil alarme critique (% restant)
        fuelColorSoundAlertsEnabled = true,
        fuelLevelCalloutFile     = nil,
        fuelAlertFile            = nil,                       -- Son alarme fuel (seuil)
        fuelCriticalAlertFile    = nil,                       -- Son alarme fuel critique
        _fuelPercent             = nil,                       -- valeur interne %% (calculée)
        _fuelDisplayValue        = nil,
        xicoyFuelStartPercent    = 100,
        fuelMax                  = 100,                       -- Basic : 100%% = plein (Xicoy Fuel %)
        flameOutAlertFile        = nil,                       -- Son alarme Flame Out Xicoy
        restartAlertFile         = nil,
        _flameOutArmed           = false,                     -- armement apres moteur en fonctionnement
        _restartArmed            = false,
        _lastEcuStatus           = nil,                       -- derniere transition statut ECU

        -- DIY Xicoy / capteurs libres
        diy1Source     = nil, diy1Value     = nil, diy1Unit = "", _diy1UnitSource = nil,
        diy2Source     = nil, diy2Value     = nil, diy2Unit = "", _diy2UnitSource = nil,
        diy3Source     = nil, diy3Value     = nil, diy3Unit = "", _diy3UnitSource = nil,

        -- Mode Xicoy Extended / Maximum (ProHub)
        ambTempSource      = nil, ambTempValue      = nil,   -- Ambient Temp (°C)
        pressSource        = nil, pressValue        = nil,   -- Pressure (mBar)
        altSource          = nil, altValue          = nil,   -- Altitude (m)
        fuelFlowSource     = nil, fuelFlowValue     = nil,   -- Fuel Flow (ml/min)
        serialSource       = nil, serialValue       = nil,   -- Serial Number
        battUsedSource     = nil, battUsedValue     = nil,   -- Battery Used (mAh)
        engineTimeSource   = nil, engineTimeValue   = nil,   -- Engine Time (s)
        pumpAmpSource      = nil, pumpAmpValue      = nil,   -- Pump Amperage (0.1A)

        -- ENJET DTA
        engineCurrentSource = nil, engineCurrentValue = nil,
        fuelConsumptionSource = nil, fuelConsumptionValue = nil,

        -- Capteur général (RxBatt)
        rxbattSource   = nil, rxbattValue   = nil,   -- RxBatt Sensor

        -- RSSI
        rssi1Source    = nil, rssi1Value    = nil, rssi1Unit = "", -- RSSI Sensor 1 (2.4G)
        rssi2Source    = nil, rssi2Value    = nil, rssi2Unit = "", -- RSSI Sensor 2 (900M)

        -- Échelles max pour les jauges (valeurs réelles)
        rpmMax         = 160000,                     -- RPM max turbine (100%%)
        egtMax         = 700,                        -- EGT max (°C)
        pumpMax        = 100,                        -- Valeur max Pump
        telemetryMode  = TELEMETRY_MODE_BASIC,       -- 0=Basic, 1=Extended, 2=Maximum
        ecuType        = 0,                          -- 0=Xicoy, 1=JetCat, 2=KingTech, 3=Swiwin, 4=Linton, 5=Enjet
        theme          = 0,                          -- 0=Std, 1=High contrast, 2=Amber
    }
end

-------------------------------------------------------------
-- Table des messages ECU Xicoy
-- Codes 0..37 et code spécial 100
-------------------------------------------------------------

local msg_table_Xicoy = {
    [0]   = "HighTemp",
    [1]   = "Trim Low",
    [2]   = "SetIdle!",
    [3]   = "Ready",
    [4]   = "Ignition",
    [5]   = "FuelRamp",
    [6]   = "Glow Test",
    [7]   = "Running",
    [8]   = "Stop",
    [9]   = "FlameOut",
    [10]  = "SpeedLow",
    [11]  = "Cooling",
    [12]  = "Ignit.Bad",
    [13]  = "Start.Fail",
    [14]  = "AccelFail",
    [15]  = "Start On",
    [16]  = "UserOff",
    [17]  = "Failsafe",
    [18]  = "Low RPM",
    [19]  = "Reset",
    [20]  = "RXPwFail",
    [21]  = "PreHeat",
    [22]  = "Battery!",
    [23]  = "Time Out",
    [24]  = "Overload",
    [25]  = "Ign.Fail",
    [26]  = "Burner On",
    [27]  = "Starting",
    [28]  = "SwitchOv",
    [29]  = "Cal.Pump",
    [30]  = "PumpLimi",
    [31]  = "NoEngine",
    [32]  = "PwrBoost",
    [33]  = "Run-Idle",
    [34]  = "Run-Max",
    [35]  = "Restart",
    [36]  = "No Status",
    [37]  = "NO SENSOR",
    [100] = "NO ECU",
}

-------------------------------------------------------------
-- Tables des statuts ECU (multi-marques)
--  - Xicoy : codes 0..36 (table ci-dessus)
-- Ordre de déclaration : Xicoy, Enjet, Linton, KingTech, Swiwin, JetCat
-------------------------------------------------------------

local msg_table_Enjet = {
    [0]  = "Stopped",
    [1]  = "Starting",
    [2]  = "Running",
    [3]  = "Cooling",
    [4]  = "Flameout Restart",
    [7]  = "Component Test",
    [8]  = "RC Calibration",
    [9]  = "Flameout Restart",
    [11] = "Engine Ready",
    [33] = "Startup Stage 1",
    [34] = "Startup Stage 2",
    [35] = "Startup Stage 3",
    [36] = "Startup Stage 4",
    [37] = "Startup Stage 5",
    [38] = "Startup Stage 6",
}

local msg_table_Linton = {
    -- Etats normaux
    [0]  = "Ready",
    [1]  = "Ready start",
    [2]  = "Temp high",
    [3]  = "Start",
    [4]  = "Burner",
    [5]  = "Success",
    [6]  = "Heating1",
    [7]  = "Heating2",
    [8]  = "Heating3",
    [9]  = "Heating4",
    [10] = "Heating5",
    [11] = "Heating6",
    [12] = "Pump Acc",
    [13] = "CTH",
    [14] = "Acc5",
    [15] = "Acc6",
    [16] = "Acc7",
    [17] = "Acc8",
    [18] = "Idling",
    [19] = "Acc",
    [20] = "Dec",
    [21] = "Speed",
    [22] = "Max Speed",
    [23] = "RC Learn",
    [24] = "RC Learning",
    [25] = "RC Successful",
    [26] = "Restart",
    [27] = "Restart",
    [28] = "Cooling",

    -- Erreurs
    [-1]  = "Volt Low",
    [-2]  = "Volt High",
    [-3]  = "OverCurrent",
    [-4]  = "TT Open",
    [-5]  = "TT Trans",
    [-6]  = "EGT Warn",
    [-7]  = "IGT Open",
    [-8]  = "IGT Short",
    [-9]  = "Motor Open",
    [-10] = "MotorCurrent",
    [-11] = "CTH Fail",
    [-12] = "Pump Open",
    [-13] = "PumpCurrent",
    [-14] = "Pump Fail",
    [-15] = "RC Lost Off",
    [-16] = "RPM Err",
    [-17] = "RPM Low",
    [-18] = "Fuel Fail",
    [-19] = "HEGT1",
    [-20] = "HEGT2",
    [-21] = "HEGT3",
    [-22] = "Temp1 Pro",
    [-23] = "Temp2 Pro",
    [-24] = "Temp3 Pro",
    [-25] = "Temp4 Pro",
    [-26] = "Temp5 Pro",
    [-27] = "Pump bubble",
    [-28] = "CTH Time",
    [-29] = "Idle Time",
    [-30] = "Idle21",
    [-31] = "Acc22",
    [-32] = "Dec23",
    [-33] = "Acc24",
    [-34] = "Restart Fail",
    [-35] = "Power limit",
    [-36] = "Acc5 Error",
    [-37] = "Acc6 Error",
    [-38] = "Acc7 Error",

    -- Absence de communication entre le convertisseur et la turbine
    [-40] = "No ECU data",
}

local msg_table_KingTech = {
    [0]  = "Temp High",
    [1]  = "Trim Low",
    [2]  = "StickLo!",
    [3]  = "Ready",
    [4]  = "Ignition",
    [5]  = "PrimeVap",
    [6]  = "Glow Bad",
    [7]  = "Running",
    [8]  = "Stop",
    [9]  = "FlameOut",
    [10] = "SpeedLow",
    [11] = "Cooling",
    [12] = "Ignitor Bad",
    [13] = "Start Bad",
    [14] = "AccelFail",
    [15] = "Start On",
    [16] = "User Off",
    [17] = "FailSafe",
    [18] = "Low RPM",
    [19] = "Reset",
    [20] = "RxPwFail",
    [21] = "PreHeat",
    [22] = "Low Batt",
    [23] = "Time Out",
    [24] = "OverLoad",
    [25] = "Ign. Fail",
    [26] = "Burner On",
    [27] = "GlowTest",
    [28] = "GdReady",
    [29] = "Weak Gas",
    [30] = "Stage1",
    [31] = "Stage2",
    [32] = "Stage3",
    [33] = "Unknown",
    [34] = "CAB-Lost",
    [35] = "Restart",
    [36] = "No Status",
}
local msg_table_Swiwin = {
    [21]  = "Restart",
    [20]  = "Running",
    [13]  = "Fuelramp",
    [12]  = "Preheat",
    [11]  = "Ignition",
    [10]  = "Ready",
    [9]   = "TestStarter",
    [8]   = "TestPump",
    [7]   = "TestGasValve",
    [6]   = "TestFuelValve",
    [5]   = "TestGlowPlug",
    [1]   = "Cooling",
    [0]   = "Stop",

    [-1]  = "Time Out",
    [-2]  = "Low Battery",
    [-3]  = "GlowPlug Bad",
    [-4]  = "Pump Anomaly",
    [-5]  = "Starter failure",
    [-6]  = "RPM Low",
    [-7]  = "RPM Instability",
    [-8]  = "High Temp",
    [-9]  = "Low Temp",
    [-10] = "TempSensorfail",
    [-11] = "Gas Valve Bad",
    [-12] = "Fuel Valve Bad",
    [-13] = "Lost Signal",
    [-14] = "StarterTemp High",
    [-15] = "Pump Temp High",
    [-16] = "Clutch failure",
    [-17] = "Current overload",
    [-18] = "Engine Offline",
    [-30] = "no data",
}

local msg_table_JetCat = {
    -- Running
    [1]   = "Wait for RPM (Standby / Start)",
    [2]   = "Ignite",
    [3]   = "Accelerate",
    [4]   = "Stabilise",
    [5]   = "Learn HI",
    [6]   = "Learn LO",
    [8]   = "Slow Down",
    [10]  = "Auto Off",
    [11]  = "Run (reg.)",
    [12]  = "Acceleration delay",
    [13]  = "SpeedReg (Speed Ctrl)",
    [14]  = "Two-Shaft-Regulate",
    [15]  = "PreHeat1",
    [16]  = "PreHeat2",
    [17]  = "MainFStrt",
    [19]  = "Keros.FullOn",

    -- Last Shutdown
    [100] = "No Off-Condition defined",
    [101] = "Shut down via RC",
    [102] = "Over temperature",
    [103] = "Ignition timeout",
    [104] = "Acceleration time out",
    [105] = "Acceleration too slow",
    [106] = "Over RPM",
    [107] = "Low RPM Off",
    [108] = "Low Battery",
    [109] = "Auto Off",
    [110] = "Low temperature Off",
    [111] = "Hi Temp Off",
    [112] = "Glow Plug defective",
    [113] = "Watch Dog Timer",
    [114] = "Fail Safe Off",
    [115] = "Manual Off (via GSU)",
    [116] = "Power fail (Battery fail)",
    [117] = "Temp Sensor fail (only during startup)",
    [118] = "Fuel fail",
    [119] = "Prop fail (only two shaft engines)",
    [120] = "2nd engine fail",
    [121] = "2nd engine differential too high",
    [122] = "2nd engine no communication",
}


local function getStatusText(ecuType, code)
    if code == nil then
        return "No data"
    end

    local t = ecuType or 0

    if t == 0 then
        return msg_table_Xicoy[code] or ("Code " .. tostring(code))
    elseif t == 1 then
        local txt = msg_table_JetCat[code]
        if txt then
            if code >= 100 then
                return "SD: " .. txt
            else
                return "Run: " .. txt
            end
        end
        return "Code " .. tostring(code)
    elseif t == 2 then
        return msg_table_KingTech[code] or ("Code " .. tostring(code))
    elseif t == 3 then
        return msg_table_Swiwin[code] or ("Code " .. tostring(code))
    elseif t == 4 then
        return msg_table_Linton[code] or ("Code " .. tostring(code))
    elseif t == 5 then
        return msg_table_Enjet[code] or ("Code " .. tostring(code))
    end

    return "Code " .. tostring(code)
end


-------------------------------------------------------------
-- Helper : lecture robuste d'une Source ETHOS
-------------------------------------------------------------

local function readSourceValue(widget, srcField)
    if not widget or not srcField then
        return nil
    end

    local src = widget[srcField]
    if not src or type(src.value) ~= "function" then
        return nil
    end

    local okValue, value = pcall(src.value, src)
    if okValue then
        return value
    end

    local now = system.getTimeCounter and system.getTimeCounter() / 100 or os.clock()
    widget._sourceRecoveryAt = widget._sourceRecoveryAt or {}
    local lastRecovery = widget._sourceRecoveryAt[srcField]
    if lastRecovery and (now - lastRecovery) < 1 then
        return nil
    end
    widget._sourceRecoveryAt[srcField] = now

    if type(src.name) ~= "function" or not system.getSource then
        return nil
    end

    local okName, name = pcall(src.name, src)
    if not okName or type(name) ~= "string" or name == "" then
        return nil
    end

    local okSource, recoveredSource = pcall(system.getSource, name)
    if not okSource or not recoveredSource or type(recoveredSource.value) ~= "function" then
        return nil
    end

    widget[srcField] = recoveredSource
    local okRecoveredValue, recoveredValue = pcall(recoveredSource.value, recoveredSource)
    if okRecoveredValue then
        return recoveredValue
    end

    return nil
end

local function updateField(widget, srcField, valField)
    local newValue = readSourceValue(widget, srcField)
    if widget[valField] ~= newValue then
        widget[valField] = newValue
        return true
    end
    return false
end

local function readSystemSourceValue(src)
    if not src then
        return nil
    end

    local realSrc = src
    if type(src.name) == "function" and system.getSource then
        local okName, name = pcall(src.name, src)
        if okName and type(name) == "string" and name ~= "" then
            local okSource, resolvedSource = pcall(system.getSource, name)
            if okSource and resolvedSource and type(resolvedSource.value) == "function" then
                realSrc = resolvedSource
            end
        end
    end

    if type(realSrc.value) == "function" then
        local okValue, value = pcall(realSrc.value, realSrc)
        if okValue then
            return value
        end
    end

    if realSrc ~= src and type(src.value) == "function" then
        local okFallback, fallbackValue = pcall(src.value, src)
        if okFallback then
            return fallbackValue
        end
    end

    return nil
end

local function updateSystemField(widget, srcField, valField)
    local newValue = readSystemSourceValue(widget[srcField])
    if widget[valField] ~= newValue then
        widget[valField] = newValue
        return true
    end
    return false
end

local function mapToPercentRaw(value, maxValue)
    if type(value) ~= "number" or type(maxValue) ~= "number" or maxValue <= 0 then
        return nil
    end
    return value * 100 / maxValue
end

local function clamp01(x)
    if x == nil then return nil end
    if x < 0 then x = 0 end
    if x > 100 then x = 100 end
    return x
end

local function sourceUnit(src)
    if not src or type(src.stringUnit) ~= "function" then return nil end
    local okUnit, u = pcall(src.stringUnit, src)
    if not okUnit or type(u) ~= "string" then return nil end
    u = u:gsub("^%s+", ""):gsub("%s+$", "")
    if u == "" then return nil end
    return u
end

local function appendUnit(text, src)
    if not text or text == "--" or text == "" or not src then return text end
    if type(src.stringUnit) == "function" then
        local okUnit, u = pcall(src.stringUnit, src)
        if not okUnit then
            return text
        end
        if type(u) == "string" then
            u = u:gsub("^%s+", ""):gsub("%s+$", "")
            if u ~= "" then
                return text .. u
            end
        end
    end
    return text
end

local function fmtTimeMMSS(v)
    if type(v) ~= "number" then return "--" end
    local total = math.floor(math.abs(v))
    local m = math.floor(total / 60)
    local s = total % 60
    local t = string.format("%d:%02d", m, s)
    if v < 0 then t = "-" .. t end
    return t
end

local function throttleToPercent(value)
    if type(value) ~= "number" then
        return nil
    end

    local percent = (value + 1024) * 100 / 2048

    if percent < 0 then
        percent = 0
    elseif percent > 100 then
        percent = 100
    end

    return percent
end

local function decodePumpDisplayValue(ecuType, rawValue)
    if type(rawValue) ~= "number" or rawValue ~= rawValue then
        return nil
    end

    -- Xicoy encodes pump RPM as a voltage-like telemetry value:
    -- 10.12 telemetry units = 1012 RPM.
    if ecuType == 0 then
        return rawValue * 100
    end

    return rawValue
end

-------------------------------------------------------------
-- Fuel : calcul du pourcentage + alarme à partir d'une valeur réelle
-------------------------------------------------------------

-------------------------------------------------------------
-- Xicoy ProHub : auto-bind par AppID FrSky
-------------------------------------------------------------

local xicoyProHubAppIds = {
    basic = {
        { field = "temp1Source", appId = 0x0400 },
        { field = "rpmSource",   appId = 0x0500 },
        { field = "ecuThrottleSource", appId = 0x0A20, label = "ECU Throttle" },
        { field = "adc3Source",  appId = 0x0900 },
        { field = "adc4Source",  appId = 0x0910 },
        { field = "fuelSource",  appId = 0x0A10 },
        { field = "temp2Source", appId = 0x0410 },
        { field = "heliTpRpmSource", appId = 0x0A30, label = "Heli/TP RPM" },
    },
    extended = {
        { field = "temp1Source",      appId = 0x4400 },
        { field = "rpmSource",        appId = 0x4401 },
        { field = "ecuThrottleSource", appId = 0x4402, label = "ECU Throttle" },
        { field = "adc3Source",       appId = 0x4403 },
        { field = "adc4Source",       appId = 0x4404 },
        { field = "fuelSource",       appId = 0x4405 },
        { field = "temp2Source",      appId = 0x4406 },
        { field = "ambTempSource",    appId = 0x4407 },
        { field = "pressSource",      appId = 0x4408 },
        { field = "altSource",        appId = 0x4409 },
        { field = "fuelFlowSource",   appId = 0x440A },
        { field = "heliTpRpmSource",  appId = 0x4414, label = "Heli/TP RPM" },
    },
    maximum = {
        { field = "temp1Source",      appId = 0x4400 },
        { field = "rpmSource",        appId = 0x4401 },
        { field = "ecuThrottleSource", appId = 0x4402, label = "ECU Throttle" },
        { field = "adc3Source",       appId = 0x4403 },
        { field = "adc4Source",       appId = 0x4404 },
        { field = "fuelSource",       appId = 0x4405 },
        { field = "temp2Source",      appId = 0x4406 },
        { field = "ambTempSource",    appId = 0x4407 },
        { field = "pressSource",      appId = 0x4408 },
        { field = "altSource",        appId = 0x4409 },
        { field = "fuelFlowSource",   appId = 0x440A },
        { field = "serialSource",     appId = 0x440B },
        { field = "battUsedSource",   appId = 0x440C },
        { field = "engineTimeSource", appId = 0x440D },
        { field = "pumpAmpSource",    appId = 0x440E },
        { field = "heliTpRpmSource",  appId = 0x4414, label = "Heli/TP RPM" },
    },
}

local enjetAppIds = {
    { field = "rpmSource",             appId = 0x0200 },
    { field = "temp1Source",           appId = 0x0201 },
    { field = "adc3Source",            appId = 0x0202 },
    { field = "engineCurrentSource",   appId = 0x0203 },
    { field = "temp2Source",           appId = 0x0204 },
    { field = "fuelFlowSource",        appId = 0x0205 },
    { field = "fuelConsumptionSource", appId = 0x0206 },
    { field = "adc4Source",            appId = 0x0207 },
    { field = "pressSource",           appId = 0x0208 },
}

local function isUsableSource(src)
    return src and (type(src.name) == "function" or type(src.value) == "function")
end

local function safeSportGetSensorByAppId(appId)
    if system.getSource and CATEGORY_TELEMETRY_SENSOR then
        local okSource, source = pcall(function()
            return system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })
        end)
        if okSource and isUsableSource(source) then
            return source
        end
    end

    if not sport then
        return nil
    end
    if not sport.getSensor then
        return nil
    end
    local okSensor, sensor = pcall(function()
        return sport.getSensor({ appId = appId })
    end)
    if (not okSensor) or (not sensor) then
        okSensor, sensor = pcall(function()
            return sport.getSensor(appId)
        end)
    end
    if not okSensor or not sensor then
        return nil
    end

    if isUsableSource(sensor) then
        return sensor
    end

    return nil
end

local function autoBindXicoyProHub(widget)
    if widget.ecuType ~= 0 then
        widget._autoBindStatus = "Auto-bind: Xicoy only"
        if lcd.invalidate then
            lcd.invalidate()
        end
        return
    end

    local map = xicoyProHubAppIds.basic
    if (widget.telemetryMode or TELEMETRY_MODE_BASIC) == TELEMETRY_MODE_EXTENDED then
        map = xicoyProHubAppIds.extended
    elseif (widget.telemetryMode or TELEMETRY_MODE_BASIC) == TELEMETRY_MODE_MAXIMUM then
        map = xicoyProHubAppIds.maximum
    end

    local total = map and #map or 0
    local bound = 0
    if total > 0 then
        for _, item in ipairs(map) do
            local sensor = safeSportGetSensorByAppId(item.appId)
            if sensor then
                widget[item.field] = sensor
                bound = bound + 1
            end
        end
    end

    if total > 0 then
        widget._autoBindStatus = "Auto-bind: " .. tostring(bound) .. "/" .. tostring(total) .. " sensors"
    else
        widget._autoBindStatus = "Auto-bind: no mapping"
    end

    if lcd.invalidate then
        lcd.invalidate()
    end
end

local function autoBindEnjetDTA(widget)
    if widget.ecuType ~= 5 then
        widget._autoBindStatus = "Auto-bind unavailable for selected ECU"
        if lcd.invalidate then
            lcd.invalidate()
        end
        return
    end

    local map = enjetAppIds
    local total = map and #map or 0
    local bound = 0
    if total > 0 then
        for _, item in ipairs(map) do
            local sensor = safeSportGetSensorByAppId(item.appId)
            if sensor then
                widget[item.field] = sensor
                bound = bound + 1
            end
        end
    end

    widget._autoBindStatus = "Auto-bind ENJET: "
        .. tostring(bound) .. "/" .. tostring(total) .. " sensors"

    if lcd.invalidate then
        lcd.invalidate()
    end
end

local function autoBindSelectedEcu(widget)
    if widget.ecuType == 0 then
        autoBindXicoyProHub(widget)
    elseif widget.ecuType == 5 then
        autoBindEnjetDTA(widget)
    else
        widget._autoBindStatus = "Auto-bind unavailable for selected ECU"
        if lcd.invalidate then
            lcd.invalidate()
        end
    end
end

local function safeSourceName(src)
    if not src or type(src.name) ~= "function" then
        return nil
    end
    local okName, name = pcall(src.name, src)
    if okName then
        return name
    end
    return nil
end

local function updateFuel(widget)
    -- Xicoy/autres : fuelValue est un pourcentage ; ENJET : FuelCons est converti.
    local prevPercent = widget._fuelPercent
    local prevDisplayValue = widget._fuelDisplayValue
    local percent = nil

    if widget.ecuType == 5 then
        local capacity = widget.fuelMax
        local consumed = widget.fuelConsumptionValue

        if type(capacity) == "number" and capacity > 0 and type(consumed) == "number" then
            local remaining = capacity - consumed
            if remaining < 0 then
                remaining = 0
            elseif remaining > capacity then
                remaining = capacity
            end

            percent = remaining * 100 / capacity
            if percent < 0 then
                percent = 0
            elseif percent > 100 then
                percent = 100
            end

            widget._fuelDisplayValue = remaining
        else
            widget._fuelDisplayValue = nil
        end
    elseif widget.ecuType == 0 then
        local rawPercent = widget.fuelValue
        local startPercent = widget.xicoyFuelStartPercent or 100

        if startPercent < 0 then
            startPercent = 0
        elseif startPercent > 100 then
            startPercent = 100
        end

        if type(rawPercent) == "number" then
            local fuelOffset = 100 - startPercent
            percent = rawPercent - fuelOffset

            if percent < 0 then
                percent = 0
            elseif percent > 100 then
                percent = 100
            end

            widget._fuelDisplayValue = percent
        else
            percent = nil
            widget._fuelDisplayValue = nil
        end
    else
        local value = widget.fuelValue
        widget._fuelDisplayValue = value

        if type(value) == "number" then
            percent = value
            if percent < 0 then
                percent = 0
            elseif percent > 100 then
                percent = 100
            end
        end
    end

    widget._fuelPercent = percent

    local fuelChanged =
        widget._fuelPercent ~= prevPercent
        or widget._fuelDisplayValue ~= prevDisplayValue

    local alert    = widget.fuelAlertPercent or 0
    local critical = widget.fuelCriticalAlertPercent or 0
    local fixedFuelSoundAlertsEnabled =
        widget.fuelColorSoundAlertsEnabled ~= false

    local crossedCritical =
        percent ~= nil
        and critical > 0
        and percent <= critical
        and ((prevPercent == nil) or (prevPercent > critical))

    local crossedRed =
        fixedFuelSoundAlertsEnabled
        and percent ~= nil
        and percent <= FUEL_RED_THRESHOLD
        and ((prevPercent == nil) or (prevPercent > FUEL_RED_THRESHOLD))

    local crossedAlert =
        percent ~= nil
        and alert > 0
        and percent <= alert
        and ((prevPercent == nil) or (prevPercent > alert))

    local crossedYellow =
        fixedFuelSoundAlertsEnabled
        and percent ~= nil
        and percent <= FUEL_YELLOW_THRESHOLD
        and ((prevPercent == nil) or (prevPercent > FUEL_YELLOW_THRESHOLD))

    -- Alarme critique : fuel très bas (seuil critique)
    if crossedCritical then
        if system.playHaptic then
            system.playHaptic(500)
        end
        playConfiguredAudio(widget.fuelCriticalAlertFile)
        if system.playNumber and UNIT_PERCENT then
            system.playNumber(math.floor(percent + 0.5), UNIT_PERCENT, 0)
        end
        return fuelChanged
    end

    if crossedRed then
        playConfiguredAudio(widget.fuelLevelCalloutFile)
        if system.playNumber and UNIT_PERCENT then
            system.playNumber(FUEL_RED_THRESHOLD, UNIT_PERCENT, 0)
        end
        return fuelChanged
    end

    -- Alarme seuil fuel (non critique)
    if crossedAlert then
        -- Alarme : vibration + son + annonce vocale du pourcentage restant
        if system.playHaptic then
            system.playHaptic(300)
        end
        playConfiguredAudio(widget.fuelAlertFile)
        if system.playNumber and UNIT_PERCENT then
            system.playNumber(math.floor(percent + 0.5), UNIT_PERCENT, 0)
        end
        return fuelChanged
    end

    if crossedYellow then
        playConfiguredAudio(widget.fuelLevelCalloutFile)
        if system.playNumber and UNIT_PERCENT then
            system.playNumber(FUEL_YELLOW_THRESHOLD, UNIT_PERCENT, 0)
        end
        return fuelChanged
    end

    return fuelChanged
end

-- Alarmes d’événements Xicoy : FlameOut et Restart
local function updateFlameOutAlarm(widget)
    if (widget.ecuType or 0) ~= 0 then
        widget._flameOutArmed = false
        widget._restartArmed = false
        widget._lastEcuStatus = nil
        return
    end

    local rawCode = widget.temp2Value
    if type(rawCode) ~= "number" then
        return
    end

    local code = math.floor(rawCode + 0.5)

    -- Arm only after a confirmed running state.
    if code == 7 or code == 33 or code == 34 then
        widget._flameOutArmed = true
        widget._restartArmed = true
    end

    -- Trigger once on the transition to FlameOut.
    if widget._flameOutArmed
        and code == 9
        and widget._lastEcuStatus ~= 9 then

        widget._flameOutArmed = false

        if system.playHaptic then
            system.playHaptic(1000)
        end

        playConfiguredAudio(widget.flameOutAlertFile)
    end

    if widget._restartArmed
        and code == 35
        and widget._lastEcuStatus ~= 35 then

        widget._restartArmed = false

        if system.playHaptic then
            system.playHaptic(500)
        end

        playConfiguredAudio(widget.restartAlertFile)
    end

    -- Normal stops disarm without alarm.
    if code == 8 or code == 16 then
        widget._flameOutArmed = false
        widget._restartArmed = false
    end

    widget._lastEcuStatus = code
end


-------------------------------------------------------------
-- Helpers graphiques
-------------------------------------------------------------

local function getGrey(level)
    if lcd.GREY then
        return lcd.GREY(level)
    end
    if lcd.RGB then
        return lcd.RGB(level, level, level)
    end
    return 0
end


local function getWhite()
    if lcd.RGB then
        return lcd.RGB(255, 255, 255)
    end
    return getGrey(31)
end
local function getWarnColor()
    if lcd.RGB then
        return lcd.RGB(255, 180, 0)
    end
    return getGrey(24)
end

-- Palette de couleurs selon le thème
local function getPalette(theme)
    if theme == nil then theme = 0 end

    -- Écran N&B : on ignore le thème et on reste simple
    if lcd.GREY and not lcd.RGB then
        return {
            bgColor      = getGrey(0),
            gaugeColor   = getGrey(15),
            alertColor   = getGrey(30),
            bgGaugeColor = getGrey(10),
            textColor    = getGrey(31),
        }
    end

    -- Thème 0 : vert Corsica Fly Dream
    if theme == 0 then
        return {
            bgColor      = lcd.RGB(0, 0, 0),
            gaugeColor   = lcd.RGB(0, 160, 0),
            alertColor   = lcd.RGB(255, 0, 0),
            bgGaugeColor = lcd.RGB(60, 60, 60),
            textColor    = lcd.RGB(255, 255, 255),
        }
    end

    -- Thème 1 : High contrast (cyan / bleu)
    if theme == 1 then
        return {
            bgColor      = lcd.RGB(0, 0, 0),
            gaugeColor   = lcd.RGB(0, 220, 255),
            alertColor   = lcd.RGB(255, 80, 120),
            bgGaugeColor = lcd.RGB(40, 40, 60),
            textColor    = lcd.RGB(255, 255, 255),
        }
    end

    -- Thème 2 : Amber (cockpit)
    if theme == 2 then
        return {
            bgColor      = lcd.RGB(0, 0, 0),
            gaugeColor   = lcd.RGB(255, 180, 0),
            alertColor   = lcd.RGB(255, 80, 0),
            bgGaugeColor = lcd.RGB(60, 30, 0),
            textColor    = lcd.RGB(255, 230, 200),
        }
    end

    -- Fallback
    return {
        bgColor      = lcd.RGB(0, 0, 0),
        gaugeColor   = lcd.RGB(0, 160, 0),
        alertColor   = lcd.RGB(255, 0, 0),
        bgGaugeColor = lcd.RGB(60, 60, 60),
        textColor    = lcd.RGB(255, 255, 255),
    }
end

-- Jauge simple (fond + une seule couleur)
local function drawArcGauge(cx, cy, innerR, outerR, startAngle, endAngle, percent, colorActive, colorBg)
    if percent == nil then percent = 0 end
    if percent < 0 then percent = 0 elseif percent > 100 then percent = 100 end

    if lcd.drawAnnulusSector == nil then
        lcd.color(colorBg)
        lcd.drawCircle(cx, cy, outerR)
        lcd.drawCircle(cx, cy, innerR)
        return
    end

    lcd.color(colorBg)
    lcd.drawAnnulusSector(cx, cy, innerR, outerR, startAngle, endAngle)

    local sweep     = endAngle - startAngle
    local activeEnd = startAngle + sweep * percent / 100

    lcd.color(colorActive)
    lcd.drawAnnulusSector(cx, cy, innerR, outerR, startAngle, activeEnd)
end

-------------------------------------------------------------
-- Affichage : mise en page GRAF avec valeurs réelles
-------------------------------------------------------------


-------------------------------------------------------------
-- Dashboard : première étape "objects" inspirée DashX
-- (pour l'instant : RPM, EGT, Pump Volt, Fuel)
-------------------------------------------------------------

local dashboardObjects = {
    { id = "fuel", kind = "bar",     label = "CARBURANT" },
    { id = "rpm",  kind = "arcBand", label = "RPM" },
    { id = "egt",  kind = "arcBand", label = "EGT" },
    { id = "pump", kind = "arc",     label = "PUMP" },
}

-- Rendu des jauges défini par dashboardObjects.
-- ctx contient : w, h, margin, couleurs, géométrie (cxRight, etc.) et valeurs (rpmPercent, texte...)
-- Jauge a zones progressives sur une plage 0..maxPercent contenue dans l'arc demande.
local function drawArcGaugeZones(cx, cy, innerR, outerR, startAngle, endAngle,
                                 percent, warnStartPercent, alertStartPercent, maxPercent,
                                 colorNormal, colorWarn, colorAlert, colorBg)
    if percent == nil then percent = 0 end
    if maxPercent == nil or maxPercent <= 0 then maxPercent = 100 end
    if percent < 0 then percent = 0 elseif percent > maxPercent then percent = maxPercent end

    if lcd.drawAnnulusSector == nil then
        lcd.color(colorBg)
        lcd.drawCircle(cx, cy, outerR)
        lcd.drawCircle(cx, cy, innerR)
        return
    end

    local sweep = endAngle - startAngle
    local function angleFor(p)
        return startAngle + sweep * p / maxPercent
    end

    lcd.color(colorBg)
    lcd.drawAnnulusSector(cx, cy, innerR, outerR, startAngle, endAngle)

    if percent <= 0 then return end

    local zones = {
        { from = 0,                 to = warnStartPercent,  color = colorNormal },
        { from = warnStartPercent,  to = alertStartPercent, color = colorWarn },
        { from = alertStartPercent, to = maxPercent,        color = colorAlert },
    }

    for _, zone in ipairs(zones) do
        local zoneEnd = math.min(percent, zone.to)
        if zoneEnd > zone.from then
            lcd.color(zone.color)
            lcd.drawAnnulusSector(cx, cy, innerR, outerR, angleFor(zone.from), angleFor(zoneEnd))
        end
    end
end

local function renderDashboard(widget, ctx)
    for _, o in ipairs(dashboardObjects) do
        if o.id == "rpm" and o.kind == "arcBand" then
            -- RPM : demi-jauge haut droite
            drawArcGaugeZones(
                ctx.cxRight, ctx.cyTop,
                ctx.innerBig, ctx.radiusBig,
                270, 450,
                ctx.rpmPercent or 0,
                80, 100, 110,
                ctx.gaugeColor, getWarnColor(), ctx.alertColor, ctx.bgGaugeColor
            )

            -- Valeur réelle + label
            local rpmText = ctx.rpmText or "--"
            lcd.color(ctx.gaugeColor)
            lcd.font(FONT_XXL)
            local tw, th = lcd.getTextSize(rpmText)
            local rpmValueY = ctx.cyTop - th - 27  -- ajusté pour cohérence verticale
            lcd.drawText(ctx.cxRight - tw / 2, rpmValueY, rpmText, 0)

            lcd.color(ctx.textColor)
            lcd.font(FONT_L)
            local label = o.label or "RPM"
            local lw = lcd.getTextSize(label)
            local rpmLabelY = rpmValueY + th + 2
            lcd.drawText(ctx.cxRight - lw / 2, rpmLabelY, label, 0)

        elseif o.id == "egt" and o.kind == "arcBand" then
            -- EGT : demi-jauge bas droite
            local percent = ctx.egtPercent or 0
            local alertStartPercent = ctx.egtBandStartPercent or 100
            local warnStartPercent = alertStartPercent * 0.85

            if warnStartPercent < 0 then
                warnStartPercent = 0
            end

            if warnStartPercent > alertStartPercent then
                warnStartPercent = alertStartPercent
            end

            drawArcGaugeZones(
                ctx.cxRight, ctx.cyBottom,
                ctx.innerBig, ctx.radiusBig,
                270, 450,
                percent,
                warnStartPercent,
                alertStartPercent,
                110,
                ctx.gaugeColor,
                getWarnColor(),
                ctx.alertColor,
                ctx.bgGaugeColor
            )

            local egtText = ctx.egtText or "--"
            lcd.color(ctx.gaugeColor)
            lcd.font(FONT_XXL)
            local tw, th = lcd.getTextSize(egtText)
            local egtValueY = ctx.cyBottom - th - 27  -- ajusté pour cohérence verticale
            lcd.drawText(ctx.cxRight - tw / 2, egtValueY, egtText, 0)

            lcd.color(ctx.textColor)
            lcd.font(FONT_L)
            local label = o.label or "EGT"
            local lw = lcd.getTextSize(label)
            local egtLabelY = egtValueY + th + 2
            lcd.drawText(ctx.cxRight - lw / 2, egtLabelY, label, 0)


        elseif o.id == "pump" and o.kind == "arc" then
            -- PUMP : anneau à gauche
            local innerR = ctx.radiusSmall - ctx.thicknessSmall
            local outerR = ctx.radiusSmall
            local percent = ctx.pumpPercent or 0

            drawArcGauge(
                ctx.cxLeft, ctx.cyLeft,
                innerR, outerR,
                0, 360,
                percent,
                ctx.gaugeColor, ctx.bgGaugeColor
            )

            -- valeur au centre
            local pumpText = ctx.pumpText or "--"
            lcd.color(ctx.gaugeColor)
            lcd.font(FONT_L)
            local tw, th = lcd.getTextSize(pumpText)
            local valueY = ctx.cyLeft - th
            lcd.drawText(ctx.cxLeft - tw / 2, valueY, pumpText, 0)

            -- label "PUMP" sous la valeur, à l'intérieur du cercle
            lcd.color(ctx.textColor)
            lcd.font(FONT_STD)
            local label = o.label or "PUMP"
            local lw = lcd.getTextSize(label)
            lcd.drawText(
                ctx.cxLeft - lw / 2,
                valueY + th,
                label,
                0
            )

        elseif o.id == "fuel" and o.kind == "bar" then
            -- Jauge carburant (barre en bas, auto-scale)
            -- On tient compte de la hauteur et de la largeur du widget
            local baseH, baseW = 272, 480
            local scaleH       = ctx.h / baseH
            local scaleW       = ctx.w / baseW
            if scaleH < 0.3 then scaleH = 0.3 end
            if scaleW < 0.3 then scaleW = 0.3 end
            local scale        = math.min(scaleH, scaleW)

            local fuelBarHeight = math.max(6, math.floor(18 * scale))
            local fuelBarW      = math.max(40, ctx.w - 2 * ctx.margin)
            local fuelBarX      = ctx.margin
            local fuelBarY      = ctx.h - fuelBarHeight - ctx.margin

            -- Titre
            lcd.color(ctx.textColor)
            lcd.font(FONT_STD)
            local label = o.label or "CARBURANT"
            local lw, lh = lcd.getTextSize(label)
            lcd.drawText(fuelBarX, fuelBarY - lh - 2, label, 0)

            -- Fond
            lcd.color(getGrey(150))
            lcd.drawFilledRectangle(fuelBarX, fuelBarY, fuelBarW, fuelBarHeight)

            -- Remplissage selon %
            local p = ctx.fuelPercent
            if p and p > 0 then
                if p <= FUEL_RED_THRESHOLD and lcd.RGB then
                    lcd.color(lcd.RGB(255, 0, 0))
                elseif p <= FUEL_YELLOW_THRESHOLD and lcd.RGB then
                    lcd.color(lcd.RGB(255,255,0))
                else
                    lcd.color(ctx.gaugeColor)
                end
                local fuelFillW = math.floor(fuelBarW * p / 100)
                lcd.drawFilledRectangle(fuelBarX, fuelBarY, fuelFillW, fuelBarHeight)
            end

            -- Texte valeur réelle centré
            local fuelText = ctx.fuelText or "--"
            lcd.color(getWhite())
            lcd.font(FONT_STD)
            local tw, th = lcd.getTextSize(fuelText)
            lcd.drawText(
                fuelBarX + (fuelBarW - tw) / 2,
                fuelBarY + (fuelBarHeight - th) / 2,
                fuelText, 0
            )
        end
    end
end

local function paintLegacy(widget)
    local w, h = lcd.getWindowSize()

    -- Palette de couleurs selon le thème
    local palette      = getPalette(widget.theme or 0)
    local gaugeColor   = palette.gaugeColor
    local alertColor   = palette.alertColor
    local bgGaugeColor = palette.bgGaugeColor
    local textColor    = palette.textColor

    -- Fond du widget
    lcd.color(palette.bgColor)
    lcd.drawFilledRectangle(0, 0, w, h)
    local margin       = 8

    --------------------------------------------------------
    -- Conversion des données télémétrie
    --------------------------------------------------------

    -- Chrono (secondes -> mm:ss)
    local chronoText = "--:--"
    if type(widget.chronoValue) == "number" then
        local total = math.floor(math.abs(widget.chronoValue))
        local m = math.floor(total / 60)
        local s = total % 60
        chronoText = string.format("%d:%02d", m, s)
        if widget.chronoValue < 0 then
            chronoText = "-" .. chronoText
        end
    end

    -- Status ECU via Temp2
    local statusText = getStatusText(widget.ecuType, widget.temp2Value)

    -- Valeurs réelles
    local rpmValue         = (type(widget.rpmValue)   == "number") and widget.rpmValue   or nil
    local egtValue         = (type(widget.temp1Value) == "number") and widget.temp1Value or nil
    local pumpRawValue     = (type(widget.adc4Value)  == "number") and widget.adc4Value  or nil
    if pumpRawValue ~= pumpRawValue then
        pumpRawValue = nil
    end
    local pumpDisplayValue = decodePumpDisplayValue(widget.ecuType, pumpRawValue)
    local fuelValue        = (type(widget.fuelValue)  == "number") and widget.fuelValue  or nil
    local fuelDisplayValue = fuelValue
    if widget.ecuType == 0 or widget.ecuType == 5 then
        fuelDisplayValue = (type(widget._fuelDisplayValue) == "number") and widget._fuelDisplayValue or nil
    end

    -- RPM : zone rouge >100% jusqu'à 110%
    -- Sécuriser rpmMax : si valeur absurde (nil ou <= 0), on repasse à 160000 par défaut
    local rpmMax = widget.rpmMax or 160000
    if rpmMax <= 0 then
        rpmMax = 160000
        widget.rpmMax = rpmMax
    end

    local rpmPercentRaw = mapToPercentRaw(rpmValue, rpmMax)
    local rpmPercent    = nil
    if rpmPercentRaw then
        if rpmPercentRaw < 0 then
            rpmPercent = 0
        elseif rpmPercentRaw > 110 then
            rpmPercent = 110
        else
            rpmPercent = rpmPercentRaw
        end
    end

    -- EGT : valeur réelle en °C, échelle 0..100%% de 0 à egtMax, bande rouge > ~700°C
    local egtPercent = nil
    local egtBandStartPercent = nil

    -- Sécuriser egtMax : si valeur absurde (nil ou trop basse), on repasse à 700°C par défaut
    local egtMax = widget.egtMax or 700
    if egtMax < 200 then
        egtMax = 700
        widget.egtMax = egtMax
    end

    local egtPercentRaw = mapToPercentRaw(egtValue, egtMax)
    if egtPercentRaw then
        if egtPercentRaw < 0 then
            egtPercent = 0
        elseif egtPercentRaw > 110 then
            egtPercent = 110
        else
            egtPercent = egtPercentRaw
        end
    end

    if egtMax and egtMax > 0 then
        local raw = 700 * 100 / egtMax
        if raw < 0 then raw = 0 end
        if raw > 100 then raw = 100 end
        egtBandStartPercent = raw
    end

    -- Pump et Fuel : % internes classiques
    local pumpScaleMax = widget.pumpMax or 0
    if widget.ecuType == 0 then
        pumpScaleMax = XICOY_PUMP_RAW_MAX
    end

    local pumpPercent = clamp01(mapToPercentRaw(pumpRawValue, pumpScaleMax))
    local fuelPercent = clamp01(widget._fuelPercent)

    -- Texte affiché = VALEURS RÉELLES (sans %)
    local rpmText  = rpmValue  and string.format("%d", math.floor(rpmValue + 0.5))   or "--"
    local egtText  = egtValue  and string.format("%d", math.floor(egtValue + 0.5))   or "--"
    local pumpText = pumpDisplayValue and string.format("%d", math.floor(pumpDisplayValue + 0.5))  or "--"
    local fuelText = fuelDisplayValue and string.format("%d", math.floor(fuelDisplayValue + 0.5))  or "--"
    if widget.ecuType == 5 and fuelDisplayValue then
        fuelText = fuelText .. " ml"
    end

    -- RSSI & RxBatt texte
    local rssi1Label, rssi1Value = nil, nil
    if widget.rssi1Source then
        rssi1Label = "RSSI 2.4G :"
        if type(widget.rssi1Value) == "number" then
            rssi1Value = string.format("%d%%", math.floor(widget.rssi1Value + 0.5))
        else
            rssi1Value = "--"
        end
    end

    local rssi2Label, rssi2Value = nil, nil
    if widget.rssi2Source then
        rssi2Label = "RSSI 900M :"
        if type(widget.rssi2Value) == "number" then
            rssi2Value = string.format("%d%%", math.floor(widget.rssi2Value + 0.5))
        else
            rssi2Value = "--"
        end
    end

    local ecuVLabel, ecuVValue = nil, nil
    if widget.adc3Source then
        ecuVLabel = "ECU V :"
        if type(widget.adc3Value) == "number" then
            ecuVValue = string.format("%.1fV", widget.adc3Value)
        else
            ecuVValue = "--"
        end
    end

    local rxBattLabel, rxBattValue = nil, nil
    if widget.rxbattSource then
        rxBattLabel = "Rx Batt :"
        if type(widget.rxbattValue) == "number" then
            rxBattValue = string.format("%.1fV", widget.rxbattValue)
        else
            rxBattValue = "--"
        end
    end

	-- Ajout des unités pour les capteurs DIY (affichage colonne gauche)
    -- DIY1 / DIY2 / DIY3 texte (affichés dans la colonne de gauche)
    local diy1Label, diy1Text = nil, nil
    if widget.diy1Source then
        diy1Label = "DIY1 :"
        if type(widget.diy1Value) == "number" then
			diy1Text = appendUnit(string.format("%.1f", widget.diy1Value), widget.diy1Source)
        else
            diy1Text = "--"
        end
    end

    local diy2Label, diy2Text = nil, nil
    if widget.diy2Source then
        diy2Label = "DIY2 :"
        if type(widget.diy2Value) == "number" then
			diy2Text = appendUnit(string.format("%.1f", widget.diy2Value), widget.diy2Source)
        else
            diy2Text = "--"
        end
    end

    local diy3Label, diy3Text = nil, nil
    if widget.diy3Source then
        diy3Label = "DIY3 :"
        if type(widget.diy3Value) == "number" then
			diy3Text = appendUnit(string.format("%.1f", widget.diy3Value), widget.diy3Source)
        else
            diy3Text = "--"
        end
    end

    --------------------------------------------------------
    -- GÉOMÉTRIE GÉNÉRALE
    --------------------------------------------------------
    local gaugeShiftX = 30
    local cxRight   = math.floor(w * 0.70 + gaugeShiftX)
    local offsetY   = 30

    -- RPM : arc haut
    local cyTopBase = h * 0.38 + offsetY
    local cyTop     = math.floor(cyTopBase - 15)

    -- EGT : arc bas (remontée de 10 px)
    local cyBottom  = math.floor(h * 0.78 + offsetY - 10)

    local radiusBig      = math.floor(math.min(w, h) * 0.38)
    local thicknessBig   = math.floor(radiusBig * 0.075)
    local innerBig       = radiusBig - thicknessBig

    -- Clamp to keep right gauges inside the widget area
    if cxRight + radiusBig + margin > w then
        cxRight = w - radiusBig - margin
    end
    if cxRight < radiusBig + margin then
        cxRight = radiusBig + margin
    end

    -- Pump Volt : descendue de 30 px et décalée vers la droite pour libérer la colonne texte
    local pumpShiftX     = 30  -- +30 px vers les arcs de cercle (droite)
    local cxLeft         = math.floor(w * 0.24 + 40 + gaugeShiftX + pumpShiftX)
    local cyLeft         = math.floor(h * 0.45 + 30)
    local radiusSmall    = math.floor(math.min(w, h) * 0.22)
    local thicknessSmall = math.floor(radiusSmall * 0.075)

    -- Clamp to keep left gauge inside the widget area
    if cxLeft + radiusSmall + margin > w then
        cxLeft = w - radiusSmall - margin
    end
    if cxLeft < radiusSmall + margin then
        cxLeft = radiusSmall + margin
    end

    --------------------------------------------------------
    -- 1) CHRONO (haut gauche)
    --------------------------------------------------------
    local chronoX = margin
    local chronoY = 2

    lcd.color(textColor)
    lcd.font(FONT_XXL)
    local _, th = lcd.getTextSize(chronoText)
    lcd.drawText(chronoX, chronoY, chronoText, 0)

    local chronoBottomY = chronoY + th

    --------------------------------------------------------
    -- 2) STATUS ECU sous le chrono
    --------------------------------------------------------
    local statusX = margin
    local statusY = chronoBottomY + 2

    lcd.font(FONT_L)
    local statusLabel = "STATUS ECU : "
    local statusLine = statusLabel .. statusText
    local _, lh = lcd.getTextSize(statusLine)

    -- Label en blanc, valeur de statut en vert
    lcd.color(textColor)
    lcd.drawText(statusX, statusY, statusLabel, 0)

    local labelW = lcd.getTextSize(statusLabel)
    lcd.color(gaugeColor)
    lcd.drawText(statusX + labelW, statusY, statusText or "", 0)

    local statusBottomY = statusY + lh

    --------------------------------------------------------
    -- 3) RSSI 2.4 / 900 + Rx Batt
    --------------------------------------------------------
    local lineGap   = 3
    local lineH     = 16
    local yText     = statusBottomY + lineGap

    lcd.font(FONT_STD)
    if rssi1Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, rssi1Label, 0)
        local lw1 = lcd.getTextSize(rssi1Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw1 + 5, yText, rssi1Value or "", 0)
        yText = yText + lineH + lineGap
    end
    if rssi2Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, rssi2Label, 0)
        local lw2 = lcd.getTextSize(rssi2Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw2 + 5, yText, rssi2Value or "", 0)
        yText = yText + lineH + lineGap
    end
    if rxBattLabel then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, rxBattLabel, 0)
        local lw3 = lcd.getTextSize(rxBattLabel)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw3 + 5, yText, rxBattValue or "", 0)
        yText = yText + lineH + lineGap
    end
    if ecuVLabel then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, ecuVLabel, 0)
        local lwE = lcd.getTextSize(ecuVLabel)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lwE + 5, yText, ecuVValue or "", 0)
        yText = yText + lineH + lineGap
    end

    -- DIY1 / DIY2 / DIY3 sur la colonne de gauche (sous RxBatt / RSSI)
    if diy1Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, diy1Label, 0)
        local lw4 = lcd.getTextSize(diy1Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw4 + 5, yText, diy1Text or "", 0)
        yText = yText + lineH + lineGap
    end
    if diy2Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, diy2Label, 0)
        local lw5 = lcd.getTextSize(diy2Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw5 + 5, yText, diy2Text or "", 0)
        yText = yText + lineH + lineGap
    end
    if diy3Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, diy3Label, 0)
        local lw6 = lcd.getTextSize(diy3Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw6 + 5, yText, diy3Text or "", 0)
        yText = yText + lineH + lineGap
    end
    if widget.heliTpRpmSource and (yText + lineH) <= (h - margin - 2) then
        local heliLabel = "Heli RPM :"
        local heliText = "--"
        if type(widget.heliTpRpmValue) == "number" then
            heliText = string.format("%d", math.floor(widget.heliTpRpmValue + 0.5))
        end
        lcd.color(textColor)
        lcd.drawText(statusX, yText, heliLabel, 0)
        local lwHeli = lcd.getTextSize(heliLabel)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lwHeli + 5, yText, heliText, 0)
        yText = yText + lineH + lineGap
    end

    local function drawKV(label, value, unit)
        if not label then return end
        -- stop if there is no more vertical room
        if (yText + lineH) > (h - margin - 2) then return end

        -- Label
        lcd.color(textColor)
        lcd.font(FONT_STD)
        lcd.drawText(statusX, yText, label, 0)
        local lw = lcd.getTextSize(label)

        -- Value
        local v = value or "--"
        lcd.color(gaugeColor)
        lcd.font(FONT_STD)
        lcd.drawText(statusX + lw + 5, yText, v, 0)
        local vw, vh = lcd.getTextSize(v)

        -- Unit (smaller font)
        if unit and v ~= "--" and v ~= "" then
            lcd.font(FONT_XXS)
            local _, uh = lcd.getTextSize(unit)
            local uy = yText + math.max(0, math.floor((vh - uh) / 2))
            lcd.drawText(statusX + lw + 5 + vw + 2, uy, unit, 0)
        end

        lcd.font(FONT_STD)
        yText = yText + lineH + lineGap
    end

    --------------------------------------------------------
    -- Extended / Maximum : affichage des capteurs sous la liste de gauche
    --------------------------------------------------------
    if widget.telemetryMode ~= TELEMETRY_MODE_BASIC then
        if widget.ambTempSource then
            if type(widget.ambTempValue) == "number" then
                drawKV("Amb.T :", string.format("%.1f", widget.ambTempValue), "°C")
            else
                drawKV("Amb.T :", "--")
            end
        end
        if widget.pressSource then
            if type(widget.pressValue) == "number" then
                local pressureUnit = "mbar"
                if widget.ecuType == 5 then
                    pressureUnit = "kPa"
                end
                drawKV("Pres :", string.format("%d", math.floor(widget.pressValue + 0.5)), pressureUnit)
            else
                drawKV("Pres :", "--")
            end
        end
        if widget.ecuType == 5 and widget.engineCurrentSource then
            if type(widget.engineCurrentValue) == "number" then
                drawKV("ECU Current :", string.format("%.1f", widget.engineCurrentValue), sourceUnit(widget.engineCurrentSource))
            else
                drawKV("ECU Current :", "--")
            end
        end
        if widget.altSource then
            if type(widget.altValue) == "number" then
                drawKV("Alt :", string.format("%d", math.floor(widget.altValue + 0.5)), "m")
            else
                drawKV("Alt :", "--")
            end
        end
        if widget.telemetryMode == TELEMETRY_MODE_MAXIMUM and widget.pumpAmpSource then
            if type(widget.pumpAmpValue) == "number" then
                drawKV("P.Amp :", string.format("%.1f", widget.pumpAmpValue), "A")
            else
                drawKV("P.Amp :", "--")
            end
        end
        if widget.telemetryMode == TELEMETRY_MODE_MAXIMUM and widget.battUsedSource then
            if type(widget.battUsedValue) == "number" then
                drawKV("Batt.Us :", string.format("%d", math.floor(widget.battUsedValue + 0.5)), "mAh")
            else
                drawKV("Batt.Us :", "--")
            end
        end
        if widget.telemetryMode == TELEMETRY_MODE_MAXIMUM and widget.engineTimeSource then
            drawKV("Eng.Tm :", fmtTimeMMSS(widget.engineTimeValue))
        end
        if widget.telemetryMode == TELEMETRY_MODE_MAXIMUM and widget.serialSource then
            local v
            if type(widget.serialValue) == "number" then
                v = string.format("%d", math.floor(widget.serialValue + 0.5))
            elseif type(widget.serialValue) == "string" then
                v = widget.serialValue
            else
                v = "--"
            end
            drawKV("SN :", v)
        end
    end

    if widget.throttleSource then
        local throttlePercent = throttleToPercent(widget.throttleValue)

        if throttlePercent ~= nil then
            drawKV(
                "THR :",
                string.format("%d", math.floor(throttlePercent + 0.5)),
                "%"
            )
        else
            drawKV("THR :", "--")
        end
    end

    if widget.ecuThrottleSource then
        local ecuThrottleText = "--"
        if type(widget.ecuThrottleValue) == "number" then
            local ecuThrottlePercent = widget.ecuThrottleValue
            if ecuThrottlePercent < 0 then
                ecuThrottlePercent = 0
            elseif ecuThrottlePercent > 100 then
                ecuThrottlePercent = 100
            end
            ecuThrottleText = string.format("%d", math.floor(ecuThrottlePercent + 0.5))
        end
        drawKV("ECU THR :", ecuThrottleText, "%")
    end


    --------------------------------------------------------

    --------------------------------------------------------
    -- 4–7) Jauges principales via dashboardObjects (premier essai)

 --------------------------------------------------------
    local ctx = {
        w            = w,
        h            = h,
        margin       = margin,
        gaugeColor   = gaugeColor,
        alertColor   = alertColor,
        bgGaugeColor = bgGaugeColor,
        textColor    = textColor,

        -- géométrie
        cxRight       = cxRight,
        cyTop         = cyTop,
        cyBottom      = cyBottom,
        innerBig      = innerBig,
        radiusBig     = radiusBig,
        cxLeft        = cxLeft,
        cyLeft        = cyLeft,
        radiusSmall   = radiusSmall,
        thicknessSmall = thicknessSmall,

        -- valeurs
        rpmPercent   = rpmPercent,
        rpmText      = rpmText,
        egtPercent   = egtPercent,
        egtText      = egtText,
        egtBandStartPercent = egtBandStartPercent,
        pumpPercent  = pumpPercent,
        pumpText     = pumpText,
        fuelPercent  = fuelPercent,
        fuelText     = fuelText
    }

    renderDashboard(widget, ctx)

    --------------------------------------------------------
    -- Fuel Flow : affichage sous la jauge PUMP (Extended / Maximum)
    --  - Centré sous la jauge
    --  - Maintenu au-dessus de la barre carburant pour éviter chevauchement
    --------------------------------------------------------
    if widget.telemetryMode ~= TELEMETRY_MODE_BASIC and widget.fuelFlowSource then
        -- Texte
        local flowLabel = "Fuel.Fw"
        if widget.ecuType == 5 then
            flowLabel = "Pump.Fw"
        end
        local flowValue = "--"
        local flowUnit  = nil

        if type(widget.fuelFlowValue) == "number" then
            flowValue = string.format("%d", math.floor(widget.fuelFlowValue + 0.5))
            flowUnit  = "ml/mn"
        end

        -- Géométrie de la barre carburant (mêmes règles que renderDashboard)
        local baseH, baseW = 272, 480
        local scaleH       = h / baseH
        local scaleW       = w / baseW
        if scaleH < 0.3 then scaleH = 0.3 end
        if scaleW < 0.3 then scaleW = 0.3 end
        local scale        = math.min(scaleH, scaleW)

        local fuelBarHeight = math.max(6, math.floor(18 * scale))
        local fuelBarY      = h - fuelBarHeight - margin

        -- Mesures texte (FONT_STD pour garder la hauteur minimale)
        lcd.font(FONT_STD)

        local labelPart = flowLabel .. " : "
        local valuePart = flowValue
        local unitPart  = flowUnit and (" " .. flowUnit) or ""

        local labelW, flowH = lcd.getTextSize(labelPart)
        local valueW, _     = lcd.getTextSize(valuePart)

        local unitW = 0
        if flowUnit then
            unitW, _ = lcd.getTextSize(unitPart)
        end

        local totalW = labelW + valueW + unitW

        -- Position : sous la jauge Pump, mais clampée au-dessus de la zone Fuel
        local x = math.floor(cxLeft - totalW / 2)

        local yDesired = math.floor((cyLeft + radiusSmall) + 4)

        -- On évite aussi la ligne "CARBURANT" (dessinée juste au-dessus de la barre)
        local _, fuelLabelH = lcd.getTextSize("CARBURANT")
        local yLimit = fuelBarY - fuelLabelH - 2 - flowH - 2
        if yLimit < margin then yLimit = margin end

        local y = yDesired
        if y > yLimit then y = yLimit end
        y = math.floor(y)

        -- Affichage (label en blanc, valeur en vert, unité en blanc)
        lcd.color(textColor)
        lcd.drawText(x, y, labelPart, 0)

        lcd.color(gaugeColor)
        lcd.drawText(x + labelW, y, valuePart, 0)

        if flowUnit then
            lcd.color(textColor)
            lcd.drawText(x + labelW + valueW, y, unitPart, 0)
        end
    end

end


-------------------------------------------------------------
-- Configuration (sélection des sources ETHOS + échelles)
-------------------------------------------------------------

-- Dashboard BETA : dessin uniquement à partir des valeurs mises en cache par wakeup().
local function dashboardValue(value, decimals)
    if type(value) == "string" and value ~= "" then return value end
    if type(value) ~= "number" or value ~= value then return "--" end
    if decimals == 1 then return string.format("%.1f", value) end
    return string.format("%d", math.floor(value + 0.5))
end

local function drawCentered(x, y, text, font, color)
    lcd.font(font)
    lcd.color(color)
    local tw = lcd.getTextSize(text)
    lcd.drawText(math.floor(x - tw / 2), math.floor(y), text, 0)
end

local function getTelemetryPanelLayout(rowCount, availableHeight, compact)
    if rowCount <= 0 then
        return compact and FONT_XXS or FONT_XS, 1
    end

    local maxRowH = math.max(1, math.floor(availableHeight / rowCount))
    local font, preferredRowH
    if compact then
        if rowCount <= 3 and maxRowH >= 16 then
            font, preferredRowH = FONT_XS, 18
        else
            font, preferredRowH = FONT_XXS, rowCount <= 6 and 14 or 13
        end
    else
        if rowCount <= 4 and maxRowH >= 22 then
            font, preferredRowH = FONT_STD, 22
        elseif rowCount <= 6 and maxRowH >= 18 then
            font, preferredRowH = FONT_XS, 19
        else
            font, preferredRowH = FONT_XXS, rowCount <= 9 and 16 or 14
        end
    end

    return font, math.max(1, math.min(preferredRowH, maxRowH))
end

local function drawTelemetryPanel(x, y, width, rows, availableHeight, palette, compact)
    local font, rowH = getTelemetryPanelLayout(#rows, availableHeight, compact)
    lcd.font(font)
    for i, row in ipairs(rows) do
        local rowY = y + (i - 1) * rowH
        lcd.color(palette.textColor)
        lcd.drawText(x, rowY, row[1], 0)
        local value, unit = row[2] or "--", row[3] or ""
        local valueW, unitW = lcd.getTextSize(value), lcd.getTextSize(unit)
        local valueX = x + width - valueW - unitW - (unit ~= "" and 3 or 0)
        lcd.color(palette.textColor)
        lcd.drawText(valueX, rowY, value, 0)
        if unit ~= "" and value ~= "--" then
            lcd.color(palette.gaugeColor)
            lcd.drawText(valueX + valueW + 3, rowY, unit, 0)
        end
        lcd.color(palette.bgGaugeColor)
        lcd.drawLine(x, rowY + rowH - 2, x + width, rowY + rowH - 2)
    end
end

local function drawStatusHeader(cx, y, status, chrono, width, palette, compact)
    local statusText = string.upper(status or "NO DATA")
    local statusBgColor = lcd.RGB(52, 56, 60)
    local statusFont = compact and FONT_XL or FONT_XXL
    lcd.font(statusFont)
    local statusW, statusH = lcd.getTextSize(statusText)
    local minimumFrameW = math.floor(width * 0.92)
    local frameW = math.min(width,
        math.max(minimumFrameW, statusW + (compact and 26 or 40)))
    local frameH = compact and 54 or 72
    local frameX = math.floor(cx - frameW / 2)
    local statusCx = frameX + frameW / 2
    local opticalOffset = compact and 1 or 2
    local statusY = y + math.floor((frameH - statusH) / 2) + opticalOffset

    lcd.color(statusBgColor)
    lcd.drawFilledRectangle(frameX + 1, y + 1, frameW - 2, frameH - 2)

    lcd.color(palette.gaugeColor)
    lcd.drawLine(frameX, y, frameX + frameW, y)
    lcd.drawLine(frameX + frameW, y, frameX + frameW, y + frameH)
    lcd.drawLine(frameX + frameW, y + frameH, frameX, y + frameH)
    lcd.drawLine(frameX, y + frameH, frameX, y)

    drawCentered(statusCx, statusY, statusText, statusFont, palette.textColor)

    local chronoY = y + frameH + (compact and 7 or 9)
    local chronoFont = compact and FONT_XL or FONT_XXL
    drawCentered(cx, chronoY, chrono, chronoFont, palette.textColor)
    lcd.font(chronoFont)
    local _, chronoValueH = lcd.getTextSize(chrono)
    return chronoY + chronoValueH
end

local function drawGib2aLogo(centerX, y, compact)
    if gib2aLogo == nil or not lcd.drawBitmap then
        return
    end

    local logoW = compact and GIB2A_LOGO_COMPACT_WIDTH or GIB2A_LOGO_WIDTH
    local logoH = compact and GIB2A_LOGO_COMPACT_HEIGHT or GIB2A_LOGO_HEIGHT
    lcd.drawBitmap(math.floor(centerX - logoW / 2), math.floor(y), gib2aLogo, logoW, logoH)
end

local function drawFuelFlow(cx, y, widget, palette, compact)
    if widget.fuelFlowSource == nil then
        return
    end

    local label = widget.ecuType == 5 and "PUMP FLOW" or "FUEL FLOW"
    local value = dashboardValue(widget.fuelFlowValue)
    local unitText = value == "--" and "" or " ml/min"
    local font = compact and FONT_XS or FONT_STD
    lcd.font(font)
    local labelText = label .. "  "
    local labelW = lcd.getTextSize(labelText)
    local valueW = lcd.getTextSize(value)
    local unitW = lcd.getTextSize(unitText)
    local x = math.floor(cx - (labelW + valueW + unitW) / 2)
    lcd.color(palette.textColor)
    lcd.drawText(x, y, labelText, 0)
    lcd.drawText(x + labelW, y, value, 0)
    if unitText ~= "" then
        lcd.color(palette.gaugeColor)
        lcd.drawText(x + labelW + valueW, y, unitText, 0)
    end
end

local function drawSegmentedGauge(cx, cy, radius, percent, maxPercent, palette)
    local inner = math.max(1, radius - math.max(5, math.floor(radius * 0.13)))
    local active = math.max(0, math.min(maxPercent, percent or 0))
    local yellow = lcd.RGB and lcd.RGB(255, 210, 0) or getWarnColor()
    local orange = lcd.RGB and lcd.RGB(255, 110, 0) or getWarnColor()
    for i = 0, 23 do
        local fromP, midP = maxPercent * i / 24, maxPercent * (i + 0.5) / 24
        local color = palette.bgGaugeColor
        if active > fromP then
            if midP < maxPercent * 0.62 then color = palette.gaugeColor
            elseif midP < maxPercent * 0.78 then color = yellow
            elseif midP < maxPercent * 0.91 then color = orange
            else color = palette.alertColor end
        end
        if lcd.drawAnnulusSector then
            lcd.color(color)
            lcd.drawAnnulusSector(cx, cy, inner, radius,
                210 + 300 * i / 24, 210 + 300 * (i + 0.82) / 24)
        end
    end
end

local function drawMainGauge(cx, cy, radius, value, label, unit, percent, palette, compact)
    drawSegmentedGauge(cx, cy, radius, percent, 110, palette)
    drawCentered(cx, cy - (compact and 21 or 30), value,
        compact and FONT_XL or FONT_XXL, palette.textColor)
    local labelY = unit ~= "" and (cy + (compact and 3 or 6))
        or (cy + (compact and 8 or 14))
    drawCentered(cx, labelY, label,
        compact and FONT_XS or FONT_STD, palette.textColor)
    if unit ~= "" then
        drawCentered(cx, cy + (compact and 16 or 24), unit,
            compact and FONT_XXS or FONT_XS, palette.gaugeColor)
    end
end

local function drawPumpGauge(cx, cy, radius, value, percent, palette, compact)
    drawSegmentedGauge(cx, cy, radius, percent, 100, palette)
    drawCentered(cx, cy - (compact and 22 or 29), value,
        compact and FONT_L or FONT_XL, palette.textColor)
    drawCentered(cx, cy + (compact and 4 or 6), "PUMP",
        compact and FONT_XXS or FONT_XS, palette.textColor)
end

local function drawFuelGauge(x, y, width, percent, value, palette, compact)
    local red = palette.alertColor
    local yellow = lcd.RGB and lcd.RGB(255, 210, 0) or getWarnColor()
    local barH = compact and 16 or 24
    local p = math.max(0, math.min(100, percent or 0))

    local fuelTextFont = compact and FONT_XS or FONT_STD
    local fuelLabelText = "FUEL"
    local valueText = value
    local percentText = " %"
    local labelValueSpacing = compact and 4 or 7
    lcd.font(fuelTextFont)
    local fuelLabelW, fuelTextH = lcd.getTextSize(fuelLabelText)
    local valueW, valueH = lcd.getTextSize(valueText)
    local percentW, percentH = lcd.getTextSize(percentText)
    local textGroupW = fuelLabelW + labelValueSpacing + valueW + percentW
    local textGroupH = math.max(fuelTextH, math.max(valueH, percentH))

    local fuelBarX = x
    local fuelBarW = math.max(1, width)
    local textGroupX = fuelBarX + math.floor((fuelBarW - textGroupW) / 2)
    local textGroupY = y + math.floor((barH - textGroupH) / 2)
    local valueX = textGroupX + fuelLabelW + labelValueSpacing
    local percentX = valueX + valueW

    lcd.color(palette.bgGaugeColor)
    lcd.drawFilledRectangle(fuelBarX, y, fuelBarW, barH)

    local activeWidth = math.floor(fuelBarW * p / 100)
    local function drawActiveZone(fromPercent, toPercent, color)
        local zoneX = math.floor(fuelBarW * fromPercent / 100)
        local zoneEnd = math.min(activeWidth, math.floor(fuelBarW * toPercent / 100))
        if zoneEnd > zoneX then
            lcd.color(color)
            lcd.drawFilledRectangle(fuelBarX + zoneX, y, zoneEnd - zoneX, barH)
        end
    end
    drawActiveZone(0, 25, red)
    drawActiveZone(25, 50, yellow)
    drawActiveZone(50, 100, palette.gaugeColor)

    lcd.font(fuelTextFont)
    lcd.color(palette.bgColor)
    lcd.drawText(textGroupX + 1, textGroupY + 1, fuelLabelText, 0)
    lcd.drawText(valueX + 1, textGroupY + 1, valueText, 0)
    lcd.drawText(percentX + 1, textGroupY + 1, percentText, 0)
    lcd.color(palette.textColor)
    lcd.drawText(textGroupX, textGroupY, fuelLabelText, 0)
    lcd.drawText(valueX, textGroupY, valueText, 0)
    lcd.color(palette.gaugeColor)
    lcd.drawText(percentX, textGroupY, percentText, 0)

    lcd.font(compact and FONT_XXS or FONT_XS)
    lcd.color(palette.textColor)
    local labels = { "0%", "25%", "50%", "75%", "100%" }
    for i = 0, 4 do
        local px = fuelBarX + math.floor(fuelBarW * i / 4)
        local tw = lcd.getTextSize(labels[i + 1])
        local labelX = math.max(x, math.min(x + width - tw, px - tw / 2))
        lcd.drawText(labelX, y + barH + 2, labels[i + 1], 0)
    end
end

local function paint(widget)
    local w, h = lcd.getWindowSize()
    local palette = getPalette(widget.theme or 0)
    lcd.color(palette.bgColor)
    lcd.drawFilledRectangle(0, 0, w, h)
    local compact = w < 700 or h < 430
    local margin, centerX = math.max(5, math.floor(w * 0.012)), math.floor(w / 2)
    local panelW = math.floor(w * 0.255)
    local gaugeY = math.floor(h * (compact and 0.60 or 0.58))
    local bigR = math.floor(math.min(w * 0.17, h * (compact and 0.225 or 0.25)))
    local panelAvailableHeight = math.max(1, gaugeY - bigR - margin - 2)

    local headerBottomY = drawStatusHeader(centerX, margin, getStatusText(widget.ecuType, widget.temp2Value),
        fmtTimeMMSS(widget.chronoValue), math.floor(w * (compact and 0.44 or 0.46)), palette, compact)
    drawGib2aLogo(centerX, headerBottomY + (compact and 3 or 5), compact)

    if w >= 600 and h >= 360 then
        local pressureUnit = widget.ecuType == 5 and "kPa" or "mBar"
        local leftRows = {}
        if widget.ambTempSource ~= nil then
            leftRows[#leftRows + 1] = { "AMB T", dashboardValue(widget.ambTempValue, 1), "°C" }
        end
        if widget.pressSource ~= nil then
            leftRows[#leftRows + 1] = { "PRESS", dashboardValue(widget.pressValue), pressureUnit }
        end
        if widget.altSource ~= nil then
            leftRows[#leftRows + 1] = { "ALT", dashboardValue(widget.altValue), "m" }
        end
        if widget.adc3Source ~= nil then
            leftRows[#leftRows + 1] = { "ECU V", dashboardValue(widget.adc3Value, 1), "V" }
        end
        if widget.pumpAmpSource ~= nil then
            leftRows[#leftRows + 1] = { "PUMP A", dashboardValue(widget.pumpAmpValue, 1), "A" }
        end
        if widget.battUsedSource ~= nil then
            leftRows[#leftRows + 1] = { "BATT", dashboardValue(widget.battUsedValue), "mAh" }
        end
        if widget.engineTimeSource ~= nil then
            leftRows[#leftRows + 1] = { "ENG T", fmtTimeMMSS(widget.engineTimeValue), "" }
        end
        if widget.serialSource ~= nil then
            leftRows[#leftRows + 1] = { "S/N", dashboardValue(widget.serialValue), "" }
        end

        local throttle = throttleToPercent(widget.throttleValue)
        local ecuThrottle = widget.ecuThrottleValue
        if type(ecuThrottle) == "number" then ecuThrottle = math.max(0, math.min(100, ecuThrottle)) end
        local rightRows = {}
        if widget.rxbattSource ~= nil then
            rightRows[#rightRows + 1] = { "RX V", dashboardValue(widget.rxbattValue, 1), "V" }
        end
        if widget.rssi1Source ~= nil then
            rightRows[#rightRows + 1] = { "RSSI 2.4", dashboardValue(widget.rssi1Value), "%" }
        end
        if widget.rssi2Source ~= nil then
            rightRows[#rightRows + 1] = { "RSSI 900", dashboardValue(widget.rssi2Value), "%" }
        end
        if widget.diy1Source ~= nil then
            rightRows[#rightRows + 1] = { "DIY1", dashboardValue(widget.diy1Value, 1), widget.diy1Unit or "" }
        end
        if widget.diy2Source ~= nil then
            rightRows[#rightRows + 1] = { "DIY2", dashboardValue(widget.diy2Value, 1), widget.diy2Unit or "" }
        end
        if widget.diy3Source ~= nil then
            rightRows[#rightRows + 1] = { "DIY3", dashboardValue(widget.diy3Value, 1), widget.diy3Unit or "" }
        end
        if widget.throttleSource ~= nil then
            rightRows[#rightRows + 1] = { "THR", dashboardValue(throttle), "%" }
        end
        if widget.ecuThrottleSource ~= nil then
            rightRows[#rightRows + 1] = { "ECU THR", dashboardValue(ecuThrottle), "%" }
        end
        if widget.heliTpRpmSource ~= nil then
            rightRows[#rightRows + 1] = { "HELI/TP", dashboardValue(widget.heliTpRpmValue), "RPM" }
        end
        if widget.engineCurrentSource ~= nil then
            rightRows[#rightRows + 1] = { "ECU CUR", dashboardValue(widget.engineCurrentValue, 1), "A" }
        end
        if widget.fuelConsumptionSource ~= nil then
            rightRows[#rightRows + 1] = { "FUEL USE", dashboardValue(widget.fuelConsumptionValue), "ml" }
        end

        drawTelemetryPanel(margin, margin, panelW, leftRows,
            panelAvailableHeight, palette, compact)
        drawTelemetryPanel(w - margin - panelW, margin, panelW, rightRows,
            panelAvailableHeight, palette, compact)
    end

    local rpm = type(widget.rpmValue) == "number" and widget.rpmValue or nil
    local egt = type(widget.temp1Value) == "number" and widget.temp1Value or nil
    local pumpRaw = type(widget.adc4Value) == "number" and widget.adc4Value or nil
    local rpmMax = widget.rpmMax and widget.rpmMax > 0 and widget.rpmMax or 160000
    local egtMax = widget.egtMax and widget.egtMax >= 200 and widget.egtMax or 700
    local pumpMax = widget.ecuType == 0 and XICOY_PUMP_RAW_MAX or (widget.pumpMax or 100)
    drawMainGauge(math.floor(w * 0.235), gaugeY, bigR, dashboardValue(rpm), "RPM", "",
        mapToPercentRaw(rpm, rpmMax), palette, compact)
    drawMainGauge(math.floor(w * 0.765), gaugeY, bigR, dashboardValue(egt), "EGT", "",
        mapToPercentRaw(egt, egtMax), palette, compact)
    local pumpY = math.floor(h * (compact and 0.66 or 0.65))
    local pumpR = math.floor(bigR * 0.59)
    drawPumpGauge(centerX, pumpY, pumpR,
        dashboardValue(decodePumpDisplayValue(widget.ecuType, pumpRaw)),
        clamp01(mapToPercentRaw(pumpRaw, pumpMax)), palette, compact)
    drawFuelFlow(centerX, pumpY + pumpR + (compact and 2 or 4), widget, palette, compact)

    local fuelAreaX = margin
    local fuelAreaW = w - 2 * margin
    drawFuelGauge(fuelAreaX,
        math.floor(h * (compact and 0.90 or 0.89)), fuelAreaW, clamp01(widget._fuelPercent),
        dashboardValue(widget._fuelDisplayValue or widget.fuelValue), palette, compact)
end

local function buildConfig(widget)
    local line
    local ecuChoices = {
        { "Xicoy",    1 }, -- ecuType 0
        { "Enjet",    6 }, -- ecuType 5
        { "Linton",   5 }, -- ecuType 4
        { "KingTech", 3 }, -- ecuType 2
        { "Swiwin",   4 }, -- ecuType 3
        { "JetCat",   2 }, -- ecuType 1
    }

    -- Setup Mode
    local modeChoices = {
        { "Basic",    1 },
        { "Extended", 2 },
        { "Maximum",  3 },
    }

    local themeChoices = {
        { "Standard",      1 },
        { "High contrast", 2 },
        { "Amber",         3 },
    }

    line = form.addLine("Setup Mode")
    if form.addChoiceField then
        form.addChoiceField(line, nil, modeChoices,
            function()
                local m = widget.telemetryMode or TELEMETRY_MODE_BASIC
                if m < TELEMETRY_MODE_BASIC then
                    m = TELEMETRY_MODE_BASIC
                elseif m > TELEMETRY_MODE_MAXIMUM then
                    m = TELEMETRY_MODE_MAXIMUM
                end
                return m + 1
            end,
            
            function(v)
                local sel = v or 1
                if sel < 1 then sel = 1 elseif sel > #modeChoices then sel = #modeChoices end

                local newMode = sel - 1
                if newMode < TELEMETRY_MODE_BASIC then
                    newMode = TELEMETRY_MODE_BASIC
                elseif newMode > TELEMETRY_MODE_MAXIMUM then
                    newMode = TELEMETRY_MODE_MAXIMUM
                end

                if (widget.telemetryMode or TELEMETRY_MODE_BASIC) ~= newMode then
                    widget.telemetryMode = newMode
                    -- Rebuild form so optional fields appear/disappear immediately
                    if form.clear then
                        form.clear()
                        buildConfig(widget)
                    end
                end
            end

        )
    else
        -- Fallback (older ETHOS): numeric selector
        form.addNumberField(line, nil, TELEMETRY_MODE_BASIC, TELEMETRY_MODE_MAXIMUM,
            function() return widget.telemetryMode or TELEMETRY_MODE_BASIC end,
            
            function(v)
                local newMode = v or TELEMETRY_MODE_BASIC
                if newMode < TELEMETRY_MODE_BASIC then
                    newMode = TELEMETRY_MODE_BASIC
                elseif newMode > TELEMETRY_MODE_MAXIMUM then
                    newMode = TELEMETRY_MODE_MAXIMUM
                end

                if (widget.telemetryMode or TELEMETRY_MODE_BASIC) ~= newMode then
                    widget.telemetryMode = newMode
                    if form.clear then
                        form.clear()
                        buildConfig(widget)
                    end
                end
            end

        )
    end

    line = form.addLine("ECU Type")

    if form.addChoiceField then
        form.addChoiceField(line, nil, ecuChoices,
            function()
                -- We keep widget.ecuType stored as 0..N-1 internally, but the menu uses 1..N values
                local t = widget.ecuType or 0
                if t < 0 then
                    t = 0
                elseif t > (#ecuChoices - 1) then
                    t = (#ecuChoices - 1)
                end
                return t + 1
            end,
            function(v)
                local sel = v or 1
                if sel < 1 then
                    sel = 1
                elseif sel > #ecuChoices then
                    sel = #ecuChoices
                end
                local newType = sel - 1
                if (widget.ecuType or 0) ~= newType then
                    widget.ecuType = newType
                    if form.clear then
                        form.clear()
                        buildConfig(widget)
                    end
                end
            end
        )
    else
        -- Fallback (older ETHOS): numeric selector (still stores 0..3 internally)
        local ecuField = form.addNumberField(line, nil, 0, (#ecuChoices - 1),
            function() return widget.ecuType or 0 end,
            function(v)
                local t = v or 0
                if t < 0 then t = 0 elseif t > (#ecuChoices - 1) then t = (#ecuChoices - 1) end
                if (widget.ecuType or 0) ~= t then
                    widget.ecuType = t
                    if form.clear then
                        form.clear()
                        buildConfig(widget)
                    end
                end
            end
        )
        if ecuField and ecuField.step then
            ecuField:step(1)
        end
    end

    line = form.addLine("ECU Telemetry Auto-bind")
    local function pressAutoBind()
        autoBindSelectedEcu(widget)
        if form.clear then
            form.clear()
            buildConfig(widget)
        end
    end

    local autoBindButtonAdded = false
    if form.addButton then
        local okButton, button = pcall(function()
            return form.addButton(line, nil, {
                text = "Auto-bind",
                icon = "",
                press = pressAutoBind
            })
        end)
        autoBindButtonAdded = okButton and button ~= nil
    end
    if (not autoBindButtonAdded) and form.addTextButton then
        local okTextButton, button = pcall(function()
            return form.addTextButton(line, nil, "Auto-bind", pressAutoBind)
        end)
        autoBindButtonAdded = okTextButton and button ~= nil
    end
    if (not autoBindButtonAdded) and form.addStaticText then
        form.addStaticText(line, nil, "Auto-bind button unavailable")
    end

    if widget._autoBindStatus and form.addStaticText then
        line = form.addLine("Auto-bind status")
        form.addStaticText(line, nil, widget._autoBindStatus)
    end

    
-- Temp 2 sensor (Status / code ECU)
    line = form.addLine("STATUS ECU Sensor")
    form.addSourceField(line, nil,
        function() return widget.temp2Source end,
        function(v) widget.temp2Source = v end)

    

-- RPM Sensor
    line = form.addLine("RPM Sensor")
    form.addSourceField(line, nil,
        function() return widget.rpmSource end,
        function(v) widget.rpmSource = v end)

    line = form.addLine("Heli/TP RPM Sensor")
    form.addSourceField(line, nil,
        function() return widget.heliTpRpmSource end,
        function(v) widget.heliTpRpmSource = v end)

    -- RPM max (valeur réelle pour 100%)
    line = form.addLine("RPM Max (100%)")
    local rpmField = form.addNumberField(line, nil, 1, 500000,
        function() return widget.rpmMax or 160000 end,
        function(v) widget.rpmMax = v end)
    if rpmField and rpmField.suffix then
        rpmField:suffix("rpm")
    end
    if rpmField and rpmField.step then
        rpmField:step(1000)
    end

    -- Temp 1 sensor (EGT)
    line = form.addLine("Temp1 Sensor (EGT)")
    form.addSourceField(line, nil,
        function() return widget.temp1Source end,
        function(v) widget.temp1Source = v end)

    -- EGT max (valeur réelle pour 100%)
    line = form.addLine("EGT Max (100%)")
    local egtField = form.addNumberField(line, nil, 100, 1500,
        function() return widget.egtMax or 700 end,
        function(v) widget.egtMax = v end)
    if egtField and egtField.step then
        egtField:step(10)
    end


    -- ADC3 Sensor (ECU V)
    line = form.addLine("ADC3 Sensor (ECU V)")
    form.addSourceField(line, nil,
        function() return widget.adc3Source end,
        function(v) widget.adc3Source = v end)

    -- ADC4 Sensor (Pump valeur réelle)
    line = form.addLine("ADC4 Sensor (Pump)")
    form.addSourceField(line, nil,
        function() return widget.adc4Source end,
        function(v) widget.adc4Source = v end)

    if widget.ecuType == 5 then
        line = form.addLine("Engine Current Sensor")
        form.addSourceField(line, nil,
            function() return widget.engineCurrentSource end,
            function(v) widget.engineCurrentSource = v end)

        line = form.addLine("Fuel Consumption Sensor")
        form.addSourceField(line, nil,
            function() return widget.fuelConsumptionSource end,
            function(v) widget.fuelConsumptionSource = v end)
    end

    -- Pump max (valeur réelle pour 100%)
    if widget.ecuType ~= 0 then
        line = form.addLine("Pump Max (100%)")
        local pumpField = form.addNumberField(line, nil, 1, 1000,
            function() return widget.pumpMax or 100 end,
            function(v) widget.pumpMax = v end)
        if pumpField and pumpField.step then
            pumpField:step(1)
        end
    end

    -- Fuel remaining (valeur réelle)
    local fuelSensorLabel = "Fuel Sensor (Real)"
    if widget.ecuType == 0 then
        fuelSensorLabel = "Fuel Sensor (%)"
    end
    line = form.addLine(fuelSensorLabel)
    form.addSourceField(line, nil,
        function() return widget.fuelSource end,
        function(v) widget.fuelSource = v end)

    if widget.ecuType == 0 then
        line = form.addLine("Fuel Level After Restart (%)")
        local fuelStartField = form.addNumberField(line, nil, 0, 100,
            function() return widget.xicoyFuelStartPercent or 100 end,
            function(v)
                widget.xicoyFuelStartPercent = v

                local fuelChanged = updateFuel(widget)

                if fuelChanged and lcd.invalidate then
                    lcd.invalidate()
                end
            end)
        if fuelStartField and fuelStartField.default then
            fuelStartField:default(100)
        end
        if fuelStartField and fuelStartField.step then
            fuelStartField:step(1)
        end
        if fuelStartField and fuelStartField.suffix then
            fuelStartField:suffix("%")
        end
    end

    line = form.addLine("Fuel Level Callouts 50/25%")
    form.addBooleanField(line, nil,
        function()
            return widget.fuelColorSoundAlertsEnabled ~= false
        end,
        function(v)
            widget.fuelColorSoundAlertsEnabled = v
        end)

    -- Fuel max (valeur réelle)
    if widget.ecuType == 5 then
        line = form.addLine("Fuel Tank Capacity")
        local fuelMaxField = form.addNumberField(line, nil, 1, 50000,
            function() return widget.fuelMax or 100 end,
            function(v) widget.fuelMax = v end)
        if fuelMaxField and fuelMaxField.step then
            fuelMaxField:step(10)
        end
        if fuelMaxField and fuelMaxField.suffix then
            fuelMaxField:suffix("ml")
        end
    end

    -- Fuel alert threshold (% restant)
    line = form.addLine("Fuel Alert (%)")
    local fuelAlertField = form.addNumberField(line, nil, 0, 100,
        function() return widget.fuelAlertPercent or 35 end,
        function(v) widget.fuelAlertPercent = v end)
    if fuelAlertField and fuelAlertField.suffix then
        fuelAlertField:suffix("%")
    end
    
    if fuelAlertField and fuelAlertField.default then
        fuelAlertField:default(35)
    end
if fuelAlertField and fuelAlertField.step then
        fuelAlertField:step(1)
    end

    -- Fuel critical alert threshold (% restant)
    line = form.addLine("Fuel Critical Alert (%)")
    local fuelCriticalField = form.addNumberField(line, nil, 0, 100,
        function() return widget.fuelCriticalAlertPercent or 15 end,
        function(v) widget.fuelCriticalAlertPercent = v end)
    if fuelCriticalField and fuelCriticalField.suffix then
        fuelCriticalField:suffix("%")
    end
    
    if fuelCriticalField and fuelCriticalField.default then
        fuelCriticalField:default(15)
    end
if fuelCriticalField and fuelCriticalField.step then
        fuelCriticalField:step(1)
    end

    line = form.addLine("Fuel Level Callout Sound")
    form.addFileField(line, nil, audioPath, "audio +ext",
        function()
            return widget.fuelLevelCalloutFile
        end,
        function(v)
            widget.fuelLevelCalloutFile = v
        end)

    -- Fuel alert sound (seuil)
    line = form.addLine("Fuel Alert Sound")
    form.addFileField(line, nil, audioPath, "audio +ext",
        function() return widget.fuelAlertFile end,
        function(v) widget.fuelAlertFile = v end)

    -- Fuel critical alert sound (seuil critique configurable)
    line = form.addLine("Fuel Critical Sound")
    form.addFileField(line, nil, audioPath, "audio +ext",
        function() return widget.fuelCriticalAlertFile end,
        function(v) widget.fuelCriticalAlertFile = v end)

    -- FlameOut alert sound (Xicoy only)
    line = form.addLine("Flame Out Sound")
    form.addFileField(line, nil, audioPath, "audio +ext",
        function() return widget.flameOutAlertFile end,
        function(v) widget.flameOutAlertFile = v end)

    -- Restart alert sound (Xicoy only)
    line = form.addLine("Restart Sound")
    form.addFileField(line, nil, audioPath, "audio +ext",
        function()
            return widget.restartAlertFile
        end,
        function(v)
            widget.restartAlertFile = v
        end)


    -- Extended / Maximum : télémétrie ProHub optionnelle
    local mode = widget.telemetryMode or TELEMETRY_MODE_BASIC
    if mode ~= TELEMETRY_MODE_BASIC then
            -- ProHub Extended / Maximum telemetry (optionnel)
            line = form.addLine("Ambient Temp (°C)")
            form.addSourceField(line, nil,
                function() return widget.ambTempSource end,
                function(v) widget.ambTempSource = v end)

            line = form.addLine("Pressure (mBar)")
            form.addSourceField(line, nil,
                function() return widget.pressSource end,
                function(v) widget.pressSource = v end)

            line = form.addLine("Altitude (m)")
            form.addSourceField(line, nil,
                function() return widget.altSource end,
                function(v) widget.altSource = v end)

            line = form.addLine("Fuel Flow (ml/min)")
            form.addSourceField(line, nil,
                function() return widget.fuelFlowSource end,
                function(v) widget.fuelFlowSource = v end)

        if mode == TELEMETRY_MODE_MAXIMUM then
            line = form.addLine("Serial Number")
            form.addSourceField(line, nil,
                function() return widget.serialSource end,
                function(v) widget.serialSource = v end)

            line = form.addLine("Battery Used (mAh)")
            form.addSourceField(line, nil,
                function() return widget.battUsedSource end,
                function(v) widget.battUsedSource = v end)

            line = form.addLine("Engine Time (s)")
            form.addSourceField(line, nil,
                function() return widget.engineTimeSource end,
                function(v) widget.engineTimeSource = v end)

            line = form.addLine("Pump Amperage (0.1A)")
            form.addSourceField(line, nil,
                function() return widget.pumpAmpSource end,
                function(v) widget.pumpAmpSource = v end)
        end

    end

    -- DIY 1 / 2 / 3 (optionnel)
    line = form.addLine("DIY1 Sensor")
    form.addSourceField(line, nil,
        function() return widget.diy1Source end,
        function(v)
            -- Si aucun capteur sélectionné (---) ou source sans nom, on considère qu'il n'y a pas de DIY1.
            if v == nil then
                widget.diy1Source = nil
                return
            end
            if type(v.name) == "function" then
                local n = safeSourceName(v)
                if n == nil or n == "" then
                    widget.diy1Source = nil
                    return
                end
            end
            widget.diy1Source = v
        end)

    line = form.addLine("DIY2 Sensor")
    form.addSourceField(line, nil,
        function() return widget.diy2Source end,
        function(v)
            -- Si aucun capteur sélectionné (---) ou source sans nom, on considère qu'il n'y a pas de DIY2.
            if v == nil then
                widget.diy2Source = nil
                return
            end
            if type(v.name) == "function" then
                local n = safeSourceName(v)
                if n == nil or n == "" then
                    widget.diy2Source = nil
                    return
                end
            end
            widget.diy2Source = v
        end)

    line = form.addLine("DIY3 Sensor")
    form.addSourceField(line, nil,
        function() return widget.diy3Source end,
        function(v)
            -- Si aucun capteur sélectionné (---) ou source sans nom, on considère qu'il n'y a pas de DIY3.
            if v == nil then
                widget.diy3Source = nil
                return
            end
            if type(v.name) == "function" then
                local n = safeSourceName(v)
                if n == nil or n == "" then
                    widget.diy3Source = nil
                    return
                end
            end
            widget.diy3Source = v
        end)

    -- Capteur général (RxBatt)
    line = form.addLine("RxBatt Source")
    form.addSourceField(line, nil,
        function() return widget.rxbattSource end,
        function(v) widget.rxbattSource = v end)

    -- RSSI Sensor 1 / 2
    line = form.addLine("RSSI Source 1 (2.4G)")
    form.addSourceField(line, nil,
     function() return widget.rssi1Source end,
        function(v) widget.rssi1Source = v end)

    line = form.addLine("RSSI Source 2 (900M)")
    form.addSourceField(line, nil,
        function() return widget.rssi2Source end,
        function(v) widget.rssi2Source = v end)

    -- Chrono
    line = form.addLine("Chrono Source")
    form.addSourceField(line, nil,
        function() return widget.chronoSource end,
        function(v) widget.chronoSource = v end)

    line = form.addLine("Throttle Stick Source")
    form.addSourceField(line, nil,
        function() return widget.throttleSource end,
        function(v) widget.throttleSource = v end)

    -- Thème d'affichage
    if form.addChoiceField then
        line = form.addLine("Theme")
        form.addChoiceField(line, nil, themeChoices,
            function()
                local t = widget.theme or 0
                if t < 0 then t = 0 elseif t > (#themeChoices - 1) then t = (#themeChoices - 1) end
                return t + 1
            end,
            function(v)
                local sel = v or 1
                if sel < 1 then
                    sel = 1
                elseif sel > #themeChoices then
                    sel = #themeChoices
                end

                local newTheme = sel - 1
                if newTheme < 0 then newTheme = 0 elseif newTheme > (#themeChoices - 1) then newTheme = (#themeChoices - 1) end

                if (widget.theme or 0) ~= newTheme then
                    widget.theme = newTheme
                    -- Force immediate redraw so the user sees the theme right away
                    if lcd.invalidate and ((not lcd.isVisible) or lcd.isVisible()) then
                        lcd.invalidate()
                    end
                    -- Rebuild form (same behavior as Setup Mode) for consistency
                    if form.clear then
                        form.clear()
                        buildConfig(widget)
                    end
                end
            end
        )
    else
        -- Fallback (older ETHOS): numeric selector
        line = form.addLine("Theme (0=Std 1=High 2=Amber)")
        local themeField = form.addNumberField(line, nil, 0, 2,
            function() return widget.theme or 0 end,
            function(v)
                local newTheme = v or 0
                if newTheme < 0 then newTheme = 0 elseif newTheme > 2 then newTheme = 2 end
                if (widget.theme or 0) ~= newTheme then
                    widget.theme = newTheme
                    if lcd.invalidate and ((not lcd.isVisible) or lcd.isVisible()) then
                        lcd.invalidate()
                    end
                end
            end
        )
    if themeField and themeField.step then
            themeField:step(1)
        end
    end

end

function configure(widget)
    if widget.telemetryMode == nil then
        widget.telemetryMode = TELEMETRY_MODE_BASIC
    end
    buildConfig(widget)
end

-------------------------------------------------------------
-- Wakeup : lecture via readSourceValue
-------------------------------------------------------------

local function wakeup(widget)
    -- Use a dirty flag so lcd.invalidate() is only called once per wakeup loop
    -- as suggested by Rob Thomson.
    local dirty = false

    dirty = updateField(widget, "chronoSource",   "chronoValue") or dirty

    dirty = updateField(widget, "rpmSource",      "rpmValue") or dirty
    dirty = updateField(widget, "heliTpRpmSource", "heliTpRpmValue") or dirty
    dirty = updateField(widget, "ecuThrottleSource", "ecuThrottleValue") or dirty
    dirty = updateField(widget, "temp1Source",    "temp1Value") or dirty
    dirty = updateField(widget, "temp2Source",    "temp2Value") or dirty
    dirty = updateField(widget, "adc3Source",     "adc3Value") or dirty
    dirty = updateField(widget, "adc4Source",     "adc4Value") or dirty

    dirty = updateField(widget, "diy1Source",     "diy1Value") or dirty
    dirty = updateField(widget, "diy2Source",     "diy2Value") or dirty
    dirty = updateField(widget, "diy3Source",     "diy3Value") or dirty
    if widget._diy1UnitSource ~= widget.diy1Source then
        widget._diy1UnitSource = widget.diy1Source
        widget.diy1Unit = sourceUnit(widget.diy1Source) or ""
        dirty = true
    end
    if widget._diy2UnitSource ~= widget.diy2Source then
        widget._diy2UnitSource = widget.diy2Source
        widget.diy2Unit = sourceUnit(widget.diy2Source) or ""
        dirty = true
    end
    if widget._diy3UnitSource ~= widget.diy3Source then
        widget._diy3UnitSource = widget.diy3Source
        widget.diy3Unit = sourceUnit(widget.diy3Source) or ""
        dirty = true
    end

    -- ProHub Extended / Maximum
    dirty = updateField(widget, "ambTempSource",      "ambTempValue") or dirty
    dirty = updateField(widget, "pressSource",        "pressValue") or dirty
    dirty = updateField(widget, "altSource",          "altValue") or dirty
    dirty = updateField(widget, "fuelFlowSource",     "fuelFlowValue") or dirty
    dirty = updateField(widget, "serialSource",       "serialValue") or dirty
    dirty = updateField(widget, "battUsedSource",     "battUsedValue") or dirty
    dirty = updateField(widget, "engineTimeSource",   "engineTimeValue") or dirty
    dirty = updateField(widget, "pumpAmpSource",      "pumpAmpValue") or dirty
    dirty = updateField(widget, "engineCurrentSource", "engineCurrentValue") or dirty
    dirty = updateField(widget, "fuelConsumptionSource", "fuelConsumptionValue") or dirty

    -- Capteurs généraux
    dirty = updateSystemField(widget, "rxbattSource", "rxbattValue") or dirty

    dirty = updateSystemField(widget, "rssi1Source", "rssi1Value") or dirty
    dirty = updateSystemField(widget, "rssi2Source", "rssi2Value") or dirty
    if widget._rssi1UnitSource ~= widget.rssi1Source then
        widget._rssi1UnitSource = widget.rssi1Source
        widget.rssi1Unit = sourceUnit(widget.rssi1Source)
    end
    if widget._rssi2UnitSource ~= widget.rssi2Source then
        widget._rssi2UnitSource = widget.rssi2Source
        widget.rssi2Unit = sourceUnit(widget.rssi2Source)
    end
    dirty = updateField(widget, "throttleSource", "throttleValue") or dirty

    -- Fuel (valeur réelle)
    dirty = updateField(widget, "fuelSource",     "fuelValue") or dirty
    dirty = updateFuel(widget) or dirty
    updateFlameOutAlarm(widget)

    if dirty and lcd.invalidate then
        if (not lcd.isVisible) or lcd.isVisible() then
            lcd.invalidate()
        end
    end
end

-------------------------------------------------------------
-- Persistence (read / write)
-- IMPORTANT ETHOS:
-- Keep storage.read() and storage.write() keys in exactly the same order.
-- Changing one sequence without changing the other can corrupt restored settings.
-------------------------------------------------------------

local function read(widget)
    widget.chronoSource  = storage.read("chronoSource")
    widget.throttleSource = storage.read("throttleSource")

    widget.rpmSource      = storage.read("rpmSource")
    widget.heliTpRpmSource = storage.read("heliTpRpmSource")
    widget.temp1Source    = storage.read("temp1Source")
    widget.temp2Source    = storage.read("temp2Source")
    widget.adc3Source     = storage.read("adc3Source")
    widget.adc4Source     = storage.read("adc4Source")
    widget.fuelSource     = storage.read("fuelSource")

    widget.diy1Source     = storage.read("diy1Source")
    widget.diy2Source     = storage.read("diy2Source")
    widget.diy3Source     = storage.read("diy3Source")

    -- ProHub Extended / Maximum
    widget.ambTempSource    = storage.read("ambTempSource")
    widget.pressSource      = storage.read("pressSource")
    widget.altSource        = storage.read("altSource")
    widget.fuelFlowSource   = storage.read("fuelFlowSource")
    widget.serialSource     = storage.read("serialSource")
    widget.battUsedSource   = storage.read("battUsedSource")
    widget.engineTimeSource = storage.read("engineTimeSource")
    widget.pumpAmpSource    = storage.read("pumpAmpSource")
    widget.engineCurrentSource = storage.read("engineCurrentSource")
    widget.fuelConsumptionSource = storage.read("fuelConsumptionSource")

    widget.rxbattSource   = storage.read("rxbattSource")

    widget.rssi1Source    = storage.read("rssi1Source")
    widget.rssi2Source    = storage.read("rssi2Source")

    local alert = storage.read("fuelAlertPercent")
    if alert ~= nil then
        widget.fuelAlertPercent = alert
    end

    local critical = storage.read("fuelCriticalAlertPercent")
    if critical ~= nil then
        widget.fuelCriticalAlertPercent = critical
    end

    local alertFile = storage.read("fuelAlertFile")
    if alertFile ~= nil then
        widget.fuelAlertFile = alertFile
    end

    local criticalFile = storage.read("fuelCriticalAlertFile")
    if criticalFile ~= nil then
        widget.fuelCriticalAlertFile = criticalFile
    end

    local flameOutFile = storage.read("flameOutAlertFile")
    if flameOutFile ~= nil then
        widget.flameOutAlertFile = flameOutFile
    end

    local rpmMax = storage.read("rpmMax")
    if rpmMax ~= nil then widget.rpmMax = rpmMax end

    local egtMax = storage.read("egtMax")
    if egtMax ~= nil then widget.egtMax = egtMax end

    local pumpMax = storage.read("pumpMax")
    if pumpMax ~= nil then widget.pumpMax = pumpMax end

    local fuelMax = storage.read("fuelMax")
    local storedTheme = storage.read("theme")
    local mode = storage.read("telemetryMode")
    local setupModeSchema = storage.read("setupModeSchema")
    local storedEcuType = storage.read("ecuType")

    if storedEcuType ~= nil then
        widget.ecuType = storedEcuType
    end

    if fuelMax ~= nil then
        widget.fuelMax = fuelMax
    end
    if widget.ecuType == 0 then
        if not widget.fuelMax or widget.fuelMax > 100 then
            widget.fuelMax = 100
        end
    end

    if storedTheme ~= nil then
        widget.theme = storedTheme
    end

    if mode ~= nil then
        if setupModeSchema == nil and mode == 1 then
            widget.telemetryMode = TELEMETRY_MODE_MAXIMUM
        else
            if mode < TELEMETRY_MODE_BASIC then
                mode = TELEMETRY_MODE_BASIC
            elseif mode > TELEMETRY_MODE_MAXIMUM then
                mode = TELEMETRY_MODE_MAXIMUM
            end
            widget.telemetryMode = mode
        end
    end

    local storedEcuThrottleSource = storage.read("ecuThrottleSource")
    if storedEcuThrottleSource ~= nil then
        widget.ecuThrottleSource = storedEcuThrottleSource
    end

    local storedXicoyFuelStartPercent = storage.read("xicoyFuelStartPercent")
    if type(storedXicoyFuelStartPercent) == "number" then
        if storedXicoyFuelStartPercent < 0 then
            storedXicoyFuelStartPercent = 0
        elseif storedXicoyFuelStartPercent > 100 then
            storedXicoyFuelStartPercent = 100
        end
        widget.xicoyFuelStartPercent = storedXicoyFuelStartPercent
    end

    local storedFuelColorSoundAlertsEnabled =
        storage.read("fuelColorSoundAlertsEnabled")

    if storedFuelColorSoundAlertsEnabled ~= nil then
        widget.fuelColorSoundAlertsEnabled =
            storedFuelColorSoundAlertsEnabled
    end

    local storedFuelLevelCalloutFile =
        storage.read("fuelLevelCalloutFile")
    if storedFuelLevelCalloutFile ~= nil then
        widget.fuelLevelCalloutFile =
            storedFuelLevelCalloutFile
    end

    local storedRestartAlertFile =
        storage.read("restartAlertFile")

    if storedRestartAlertFile ~= nil then
        widget.restartAlertFile =
            storedRestartAlertFile
    end

end

local function write(widget)
    storage.write("chronoSource",  widget.chronoSource)
    storage.write("throttleSource", widget.throttleSource)

    storage.write("rpmSource",      widget.rpmSource)
    storage.write("heliTpRpmSource", widget.heliTpRpmSource)
    storage.write("temp1Source",    widget.temp1Source)
    storage.write("temp2Source",    widget.temp2Source)
    storage.write("adc3Source",     widget.adc3Source)
    storage.write("adc4Source",     widget.adc4Source)
    storage.write("fuelSource",     widget.fuelSource)

    storage.write("diy1Source",     widget.diy1Source)
    storage.write("diy2Source",     widget.diy2Source)
    storage.write("diy3Source",     widget.diy3Source)

    -- ProHub Extended / Maximum
    storage.write("ambTempSource",    widget.ambTempSource)
    storage.write("pressSource",      widget.pressSource)
    storage.write("altSource",        widget.altSource)
    storage.write("fuelFlowSource",   widget.fuelFlowSource)
    storage.write("serialSource",     widget.serialSource)
    storage.write("battUsedSource",   widget.battUsedSource)
    storage.write("engineTimeSource", widget.engineTimeSource)
    storage.write("pumpAmpSource",    widget.pumpAmpSource)
    storage.write("engineCurrentSource", widget.engineCurrentSource)
    storage.write("fuelConsumptionSource", widget.fuelConsumptionSource)

    storage.write("rxbattSource",   widget.rxbattSource)

    storage.write("rssi1Source",    widget.rssi1Source)
    storage.write("rssi2Source",    widget.rssi2Source)

    storage.write("fuelAlertPercent", widget.fuelAlertPercent)
    storage.write("fuelCriticalAlertPercent", widget.fuelCriticalAlertPercent)
    storage.write("fuelAlertFile",            widget.fuelAlertFile)
    storage.write("fuelCriticalAlertFile",    widget.fuelCriticalAlertFile)
    storage.write("flameOutAlertFile",        widget.flameOutAlertFile)

    storage.write("rpmMax",           widget.rpmMax)
    storage.write("egtMax",           widget.egtMax)
    storage.write("pumpMax",          widget.pumpMax)
    storage.write("fuelMax",          widget.fuelMax)
    storage.write("theme", widget.theme)
    storage.write(
        "telemetryMode",
        widget.telemetryMode or TELEMETRY_MODE_BASIC
    )
    storage.write("setupModeSchema", SETUP_MODE_SCHEMA)
    storage.write("ecuType", widget.ecuType or 0)
    storage.write("ecuThrottleSource", widget.ecuThrottleSource)
    storage.write("xicoyFuelStartPercent", widget.xicoyFuelStartPercent or 100)
    storage.write(
        "fuelColorSoundAlertsEnabled",
        widget.fuelColorSoundAlertsEnabled ~= false
    )
    storage.write(
        "fuelLevelCalloutFile",
        widget.fuelLevelCalloutFile
    )
    storage.write(
        "restartAlertFile",
        widget.restartAlertFile
    )
end

-------------------------------------------------------------
-- Enregistrement du widget
-------------------------------------------------------------

local function init()
    loadGib2aLogo()
    system.registerWidget({
        key        = "GIB2A",
			name       = "GIB2A TURBINE Widget V" .. WIDGET_VERSION,
        create     = create,
        wakeup     = wakeup,
        configure  = configure,
        paint      = paint,
        read       = read,
        write      = write
    })
end

return { init = init }
