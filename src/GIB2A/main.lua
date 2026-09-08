-- GIB2A TURBINE Widjet V26.3.5
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
        or fileName == "" then
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
local WIDGET_VERSION = "26.3.5"
local FUEL_YELLOW_THRESHOLD = 50
local FUEL_RED_THRESHOLD = 25
local GIB2A_LOGO_PATH = "gib2a_logo_ethos_180.png"
local GIB2A_LOGO_WIDTH = 130
local GIB2A_LOGO_HEIGHT = 57
local GIB2A_LOGO_COMPACT_WIDTH = 90
local GIB2A_LOGO_COMPACT_HEIGHT = 40
local GIB2A_LOGO_SMALL_WIDTH = 55
local GIB2A_LOGO_SMALL_HEIGHT = 24
local gib2aLogo = nil

local function loadGib2aLogo()
    if gib2aLogo ~= nil then
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
local JETCAT_PUMP_DEFAULT_MAX = 1.7

local PERSISTENCE_PARAMS = {
    { key = "chronoSource", default = nil },
    { key = "throttleSource", default = nil },
    { key = "rpmSource", default = nil },
    { key = "heliTpRpmSource", default = nil },
    { key = "temp1Source", default = nil },
    { key = "temp2Source", default = nil },
    { key = "adc3Source", default = nil },
    { key = "adc4Source", default = nil },
    { key = "fuelSource", default = nil },
    { key = "diy1Source", default = nil },
    { key = "diy2Source", default = nil },
    { key = "diy3Source", default = nil },
    { key = "ambTempSource", default = nil },
    { key = "pressSource", default = nil },
    { key = "altSource", default = nil },
    { key = "fuelFlowSource", default = nil },
    { key = "serialSource", default = nil },
    { key = "battUsedSource", default = nil },
    { key = "engineTimeSource", default = nil },
    { key = "pumpAmpSource", default = nil },
    { key = "engineCurrentSource", default = nil },
    { key = "fuelConsumptionSource", default = nil },
    { key = "rxbattSource", default = nil },
    { key = "rssi1Source", default = nil },
    { key = "rssi2Source", default = nil },
    { key = "fuelAlertPercent", default = 35 },
    { key = "fuelCriticalAlertPercent", default = 15 },
    { key = "fuelAlertFile", default = nil },
    { key = "fuelCriticalAlertFile", default = nil },
    { key = "flameOutAlertFile", default = nil },
    { key = "rpmMax", default = 160000 },
    { key = "egtMax", default = 700 },
    { key = "pumpMax", default = 100 },
    { key = "theme", default = 0 },
    { key = "ecuThrottleSource", default = nil },
    { key = "fuelLevelCalloutFile", default = nil },
    { key = "restartAlertFile", default = nil },
}

local NORMALIZED_TELEMETRY_SOURCE_FIELDS = {
    rpmSource = true,
    heliTpRpmSource = true,
    ecuThrottleSource = true,
    temp1Source = true,
    temp2Source = true,
    adc3Source = true,
    adc4Source = true,
    fuelSource = true,
    diy1Source = true,
    diy2Source = true,
    diy3Source = true,
    ambTempSource = true,
    pressSource = true,
    altSource = true,
    fuelFlowSource = true,
    serialSource = true,
    battUsedSource = true,
    engineTimeSource = true,
    pumpAmpSource = true,
    engineCurrentSource = true,
    fuelConsumptionSource = true,
}

-------------------------------------------------------------
-- Création du widget
-------------------------------------------------------------

local function create(zone, options)
    local widget = {
        zone    = zone,
        options = options,
        _normalizedTelemetrySources = {},

        -- Chrono (timer ETHOS ou autre source temps)
        chronoValue   = nil,
        throttleValue = nil,

        -- Capteurs Xicoy / ETHOS
        rpmValue      = nil,   -- RPM Sensor
        heliTpRpmValue = nil, -- Heli/TP RPM optional second shaft RPM
        ecuThrottleValue = nil,
        temp1Value    = nil,   -- Temp 1 (EGT)
        temp2Value    = nil,   -- Temp 2 (Status code)
        adc3Value     = nil,   -- ADC3 (ECU V)
        adc4Value     = nil,   -- ADC4 (Pump command / volt)

        fuelValue                = nil,   -- Fuel remaining (valeur réelle)
        fuelColorSoundAlertsEnabled = true,
        _fuelPercent             = nil,                       -- valeur interne %% (calculée)
        _fuelDisplayValue        = nil,
        xicoyFuelStartPercent    = 100,
        jetCatPumpMax            = JETCAT_PUMP_DEFAULT_MAX,
        fuelMax                  = 100,                       -- Basic : 100%% = plein (Xicoy Fuel %)
        _flameOutArmed           = false,                     -- armement apres moteur en fonctionnement
        _restartArmed            = false,
        _lastEcuStatus           = nil,                       -- derniere transition statut ECU

        -- DIY Xicoy / capteurs libres
        diy1Value     = nil, diy1Unit = "", _diy1UnitSource = nil,
        diy2Value     = nil, diy2Unit = "", _diy2UnitSource = nil,
        diy3Value     = nil, diy3Unit = "", _diy3UnitSource = nil,

        -- Mode Xicoy Extended / Maximum (ProHub)
        ambTempValue      = nil,   -- Ambient Temp (°C)
        pressValue        = nil,   -- Pressure (mBar)
        altValue          = nil,   -- Altitude (m)
        fuelFlowValue     = nil,   -- Fuel Flow (ml/min)
        serialValue       = nil,   -- Serial Number
        battUsedValue     = nil,   -- Battery Used (mAh)
        engineTimeValue   = nil,   -- Engine Time (s)
        pumpAmpValue      = nil,   -- Pump Amperage (0.1A)

        -- ENJET DTA
        engineCurrentValue = nil,
        fuelConsumptionValue = nil,

        -- Capteur général (RxBatt)
        rxbattValue   = nil,   -- RxBatt Sensor

        -- RSSI
        rssi1Value    = nil, rssi1Unit = "", -- RSSI Sensor 1 (2.4G)
        rssi2Value    = nil, rssi2Unit = "", -- RSSI Sensor 2 (900M)

        -- Échelles max pour les jauges (valeurs réelles)
        telemetryMode  = TELEMETRY_MODE_BASIC,       -- 0=Basic, 1=Extended, 2=Maximum
        ecuType        = 0,                          -- 0=Xicoy, 1=JetCat, 2=KingTech, 3=Swiwin, 4=Linton, 5=Enjet
    }

    for i = 1, #PERSISTENCE_PARAMS do
        local param = PERSISTENCE_PARAMS[i]
        widget[param.key] = param.default
    end

    return widget
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
    [3]  = "Low Temp",
    [4]  = "Shutdown / Restart",
    [7]  = "Component Test",
    [8]  = "RC Calibration",
    [9]  = "Shutdown / Restart",
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

local JETCAT_STATE_TEXT = {
    [0]    = "-OFF-",
    [1]    = "Stby/START",
    [2]    = "Ignite...",
    [3]    = "acceler.",
    [4]    = "Stabilise",
    [5]    = "LearnHI",
    [6]    = "LearnLO",
    [7]    = "-OFF- Cool",
    [8]    = "SlowDown",
    [9]    = "Manual",
    [10]   = "SwitchOff",
    [11]   = "RUN (reg.)",
    [12]   = "AccelrDly",
    [13]   = "SpeedCtrl",
    [14]   = "Rpm2Ctrl",
    [15]   = "PreHeat1",
    [16]   = "PreHeat2",
    [17]   = "Bleed-Fuel",
    [18]   = "---",
    [19]   = "Keros.FullOn",
    [20]   = "Auto-Restart",
    [32]   = "BattryLo",
    [64]   = "Rpm2Fail",
    [128]  = "FuelFail",
    [1000] = "Engine start",
    [2000] = "LearnLO",
    [3000] = "RUN (reg.)",
}

local JETCAT_SHUTDOWN_TEXT = {
    [0]  = "-----",
    [1]  = "RcThrOff",
    [2]  = "OverTemp",
    [3]  = "IgnTimeO",
    [4]  = "AccTimeO",
    [5]  = "Acc.Slow",
    [6]  = "Over-Rpm",
    [7]  = "Low-Rpm",
    [8]  = "BattryLo",
    [9]  = "Auto-Off",
    [10] = "Low-EGT",
    [11] = "HiEgtOff",
    [12] = "Ignitor!",
    [13] = "WatchDog",
    [14] = "FailSafe",
    [15] = "Manual",
    [16] = "PowrFail",
    [17] = "TempFail",
    [18] = "FuelFail",
    [19] = "Rpm2Fail",
    [20] = "2nd EngF",
    [21] = "2nd Diff",
    [22] = "2nd-Comm",
    [23] = "No-OIL",
    [24] = "OverCurr",
    [25] = "No Pump!",
    [26] = "WrongPmp",
    [27] = "Pump Err",
    [28] = "No Fuel!",
    [29] = "LoRpmPmp",
    [30] = "LowRpmFB",
    [31] = "!Clutch!",
    [32] = "EngMatch",
    [33] = "CAN-TO",
    [34] = "NoRcPuls",
    [35] = "RotorBlk",
    [36] = "Kill Sig",
    [37] = "ReStartX",
    [38] = "RcAuxOff",
    [39] = "RS232Off",
    [40] = "CAN-Off",
    [41] = "Test-Off",
    [42] = "RS232-TO",
    [43] = "PrHeatTO",
    [44] = "NoOilPmp",
    [45] = "OilP Blk",
    [46] = "OilLevel",
    [47] = "Kill2Sig",
    [48] = "Kill3Sig",
}

local function normalizedJetCatStateCode(value)
    if type(value) ~= "number" then
        return nil, false
    end

    local code = math.floor(value + 0.5)

    if code < 0 then
        local shutdownCode = math.abs(code)

        if shutdownCode >= 100 then
            shutdownCode = shutdownCode - 100
        end

        return shutdownCode, true
    end

    return code, false
end

local function getStatusText(ecuType, code)
    if code == nil then
        return "No data"
    end

    local t = ecuType or 0

    if t == 0 then
        return msg_table_Xicoy[code] or ("Code " .. tostring(code))
    elseif t == 1 then
        local jetcatCode, isShutdown = normalizedJetCatStateCode(code)

        if jetcatCode == nil then
            return "No data"
        end

        if isShutdown then
            local txt = JETCAT_SHUTDOWN_TEXT[jetcatCode]
            if txt then
                return "SD: " .. txt
            end
            return "SD: Code " .. tostring(jetcatCode)
        end

        return JETCAT_STATE_TEXT[jetcatCode]
            or ("Code " .. tostring(jetcatCode))
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

local function normalizeTelemetrySource(widget, srcField)
    local src = widget[srcField]

    if not src then
        widget._normalizedTelemetrySources[srcField] = nil
        return nil
    end

    if not NORMALIZED_TELEMETRY_SOURCE_FIELDS[srcField] then
        return src
    end

    if widget._normalizedTelemetrySources[srcField] == src then
        return src
    end

    local resolvedSource = src
    if type(src.name) == "function" and system.getSource then
        local okName, name = pcall(src.name, src)
        if okName and type(name) == "string" and name ~= "" then
            local okSource, source = pcall(system.getSource, name)
            if okSource and source and type(source.value) == "function" then
                resolvedSource = source
                widget[srcField] = source
            end
        end
    end

    widget._normalizedTelemetrySources[srcField] = resolvedSource
    return resolvedSource
end

local function readSourceValue(widget, srcField)
    if not widget or not srcField then
        return nil
    end

    local src = normalizeTelemetrySource(widget, srcField)
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
    widget._normalizedTelemetrySources[srcField] = recoveredSource
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
    -- ENJET V1.53: standard FrSky sensors are discovered by ETHOS.
    -- Only IDs confirmed by existing GIB2A mappings or ENJET V1.53 are used.
    -- Exact names are the mono-turbine sensors observed at JetPower 2026.
    { field = "rpmSource",             appId = 0x0500, name = "RMP" },
    { field = "temp1Source",           appId = 0x0400, name = "Temp1" },
    { field = "adc3Source",            appId = 0x0210, name = "ADC2" },
    { field = "engineCurrentSource",   appId = 0x0200, name = "Bat1 current" },
    { field = "temp2Source",           appId = 0xFF00, name = "DIY FF00" },
    { field = "adc4Source",            appId = 0xFF10, name = "DIY FF10" },
    { field = "pressSource",                           name = "H.pressure" },
    { field = "fuelFlowSource",                       name = "GASS flow" },
    { field = "fuelConsumptionSource",                name = "GASS res. vol." },
}

local jetcatEngine1AppIds = {
    { field = "rpmSource",           name = "EngRpm1",      appId = 0x0500 },
    { field = "temp1Source",         name = "EngEgt1",      appId = 0x0400 },
    { field = "adc4Source",          name = "EngPumpV1",    appId = 0x5001 },
    { field = "adc3Source",          name = "EngEcuV1",     appId = 0x0210 },
    { field = "engineCurrentSource", name = "EngCurrent1",  appId = 0x0200, fallbackAppId = 0x5002 },
    { field = "fuelSource",          name = "EngFuel1",     appId = 0x0600 },
    { field = "fuelFlowSource",      name = "EngFuelFlow1", appId = 0x5006 },
    { field = "altSource",           name = "EngAlt1",      appId = 0x5000 },
    { field = "battUsedSource",      name = "EngBattCap1",  appId = 0x5003 },
    { field = "heliTpRpmSource",     name = "EngShaftRpm1", appId = 0x500A },
    { field = "temp2Source",         name = "EngState1",    appId = 0x5004 },
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

local function safeGetTelemetrySourceByName(name)
    if type(name) ~= "string" or name == "" or not system.getSource then
        return nil
    end

    local okSource, source = pcall(system.getSource, name)
    if okSource and isUsableSource(source) then
        return source
    end

    return nil
end

local function normalizedExactSourceName(src)
    if not src or type(src.name) ~= "function" then
        return nil
    end

    local okName, name = pcall(src.name, src)
    if not okName or type(name) ~= "string" then
        return nil
    end

    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end

    return string.lower(name)
end

local function autoBindXicoyProHub(widget)
    if widget.ecuType ~= 0 then
        widget._autoBindStatus = "Auto-bind: Xicoy only"
        lcd.invalidate()
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

    lcd.invalidate()
end

local function autoBindJetCatEngine1(widget)
    if widget.ecuType ~= 1 then
        widget._autoBindStatus = "Auto-bind: JetCat only"
        return
    end

    local total = #jetcatEngine1AppIds
    local bound = 0
    for _, item in ipairs(jetcatEngine1AppIds) do
        local sensor = safeGetTelemetrySourceByName(item.name)
        if not sensor then
            sensor = safeSportGetSensorByAppId(item.appId)
        end
        if not sensor and item.fallbackAppId then
            sensor = safeSportGetSensorByAppId(item.fallbackAppId)
        end
        if sensor then
            widget[item.field] = sensor
            bound = bound + 1
        end
    end

    widget._autoBindStatus = "Auto-bind JetCat E1: "
        .. tostring(bound) .. "/" .. tostring(total) .. " sensors"

    lcd.invalidate()
end

local function autoBindEnjetDTA(widget)
    if widget.ecuType ~= 5 then
        widget._autoBindStatus = "Auto-bind unavailable for selected ECU"
        lcd.invalidate()
        return
    end

    local map = enjetAppIds
    local total = map and #map or 0
    local bound = 0
    local boundFields = {}
    local usedSources = {}

    -- Pass 1: confirmed AppIDs remain authoritative.
    if total > 0 then
        for _, item in ipairs(map) do
            local sensor = item.appId
                and safeSportGetSensorByAppId(item.appId) or nil
            if sensor and not usedSources[sensor] then
                widget[item.field] = sensor
                boundFields[item.field] = true
                usedSources[sensor] = true
                bound = bound + 1
            end
        end
    end

    -- Pass 2 (ETHOS 26.1+): exact, unique JetPower names for unresolved fields.
    if bound < total and system.getSources and CATEGORY_TELEMETRY_SENSOR then
        local okSources, sources = pcall(
            system.getSources,
            CATEGORY_TELEMETRY_SENSOR
        )

        if okSources and type(sources) == "table" then
            local sourcesByName = {}
            for _, source in ipairs(sources) do
                if isUsableSource(source) then
                    local name = normalizedExactSourceName(source)
                    if name then
                        if sourcesByName[name] == nil then
                            sourcesByName[name] = source
                        else
                            sourcesByName[name] = false
                        end
                    end
                end
            end

            for _, item in ipairs(map) do
                if not boundFields[item.field] then
                    local sensor = sourcesByName[string.lower(item.name)]
                    if sensor and not usedSources[sensor] then
                        widget[item.field] = sensor
                        boundFields[item.field] = true
                        usedSources[sensor] = true
                        bound = bound + 1
                    end
                end
            end
        end
    end

    widget._autoBindStatus = "Auto-bind ENJET: "
        .. tostring(bound) .. "/" .. tostring(total) .. " sensors"

    lcd.invalidate()
end

local function autoBindSelectedEcu(widget)
    if widget.ecuType == 0 then
        autoBindXicoyProHub(widget)
    elseif widget.ecuType == 1 then
        autoBindJetCatEngine1(widget)
    elseif widget.ecuType == 5 then
        autoBindEnjetDTA(widget)
    else
        widget._autoBindStatus = "Auto-bind unavailable for selected ECU"
        lcd.invalidate()
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
        if UNIT_PERCENT then
            system.playNumber(math.floor(percent + 0.5), UNIT_PERCENT, 0)
        end
        return fuelChanged
    end

    if crossedRed then
        playConfiguredAudio(widget.fuelLevelCalloutFile)
        if UNIT_PERCENT then
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
        if UNIT_PERCENT then
            system.playNumber(math.floor(percent + 0.5), UNIT_PERCENT, 0)
        end
        return fuelChanged
    end

    if crossedYellow then
        playConfiguredAudio(widget.fuelLevelCalloutFile)
        if UNIT_PERCENT then
            system.playNumber(FUEL_YELLOW_THRESHOLD, UNIT_PERCENT, 0)
        end
        return fuelChanged
    end

    return fuelChanged
end

-- Alarmes d’événements Xicoy : FlameOut et Restart
local function updateFlameOutAlarm(widget)
    local ecuType = widget.ecuType or 0

    if ecuType == 0 then
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
        return
    elseif ecuType == 1 then
        local code, isShutdown = normalizedJetCatStateCode(widget.temp2Value)
        if code == nil then
            return
        end

        local stateKey = (isShutdown and "S" or "R") .. tostring(code)

        if isShutdown then
            widget._flameOutArmed = false
            widget._lastEcuStatus = stateKey
            return
        end

        if code == 11 or code == 3000 then
            widget._flameOutArmed = true
            widget._restartArmed = true
        end

        if widget._flameOutArmed
            and code == 0
            and widget._lastEcuStatus ~= "R0" then

            widget._flameOutArmed = false

            if system.playHaptic then
                system.playHaptic(1000)
            end

            playConfiguredAudio(widget.flameOutAlertFile)
        end

        if widget._restartArmed
            and code == 20
            and widget._lastEcuStatus ~= "R20" then

            widget._restartArmed = false

            if system.playHaptic then
                system.playHaptic(500)
            end

            playConfiguredAudio(widget.restartAlertFile)
        end

        if code == 7 or code == 8 or code == 10 then
            widget._flameOutArmed = false
            widget._restartArmed = false
        end

        widget._lastEcuStatus = stateKey
        return
    else
        widget._flameOutArmed = false
        widget._restartArmed = false
        widget._lastEcuStatus = nil
        return
    end
end


-------------------------------------------------------------
-- Helpers graphiques
-------------------------------------------------------------

-- Palette de couleurs selon le thème
local function resolveSafeColor(fallback)
    if SAFE_COLOR ~= nil then
        return SAFE_COLOR
    end
    if THEME_SAFE_COLOR ~= nil then
        return lcd.themeColor(THEME_SAFE_COLOR)
    end
    return fallback
end

local function resolveErrorColor(fallback)
    if ERROR_COLOR ~= nil then
        return ERROR_COLOR
    end
    if THEME_ERROR_COLOR ~= nil then
        return lcd.themeColor(THEME_ERROR_COLOR)
    end
    return fallback
end

local function getPalette(theme)
    if theme == nil then theme = 0 end

    -- Écran N&B : on ignore le thème et on reste simple
    -- Thème 0 : vert Corsica Fly Dream
    if theme == 0 then
        return {
            bgColor      = lcd.RGB(0, 0, 0),
            gaugeColor   = lcd.RGB(0, 160, 0),
            alertColor   = lcd.RGB(255, 0, 0),
            safeColor    = resolveSafeColor(lcd.RGB(0, 160, 0)),
            criticalColor = resolveErrorColor(lcd.RGB(255, 0, 0)),
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
            safeColor    = resolveSafeColor(lcd.RGB(0, 220, 255)),
            criticalColor = resolveErrorColor(lcd.RGB(255, 80, 120)),
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
            safeColor    = resolveSafeColor(lcd.RGB(255, 180, 0)),
            criticalColor = resolveErrorColor(lcd.RGB(255, 80, 0)),
            bgGaugeColor = lcd.RGB(60, 30, 0),
            textColor    = lcd.RGB(255, 230, 200),
        }
    end

    -- Fallback
    return {
        bgColor      = lcd.RGB(0, 0, 0),
        gaugeColor   = lcd.RGB(0, 160, 0),
        alertColor   = lcd.RGB(255, 0, 0),
        safeColor    = resolveSafeColor(lcd.RGB(0, 160, 0)),
        criticalColor = resolveErrorColor(lcd.RGB(255, 0, 0)),
        bgGaugeColor = lcd.RGB(60, 60, 60),
        textColor    = lcd.RGB(255, 255, 255),
    }
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

local function fitStatusFont(text, maxWidth, compact, small)
    local fonts
    if small then
        fonts = { FONT_L, FONT_STD, FONT_XS, FONT_XXS }
    elseif compact then
        fonts = { FONT_XL, FONT_L, FONT_STD, FONT_XS, FONT_XXS }
    else
        fonts = { FONT_XXL, FONT_XL, FONT_L, FONT_STD, FONT_XS, FONT_XXS }
    end

    for i = 1, #fonts do
        lcd.font(fonts[i])
        local textW = lcd.getTextSize(text)
        if textW <= maxWidth then
            return fonts[i]
        end
    end

    return FONT_XXS
end

local function drawStatusHeader(cx, y, status, chrono, width, palette, compact, small)
    local statusText = string.upper(status or "NO DATA")
    local statusBgColor = lcd.RGB(52, 56, 60)
    local horizontalPadding = small and 16 or (compact and 26 or 40)
    local minimumFrameW = math.floor(width * 0.92)
    local frameW = width
    local availableTextW = math.max(1, frameW - horizontalPadding)
    local statusFont = fitStatusFont(statusText, availableTextW, compact, small)
    lcd.font(statusFont)
    local statusW, statusH = lcd.getTextSize(statusText)
    local frameH = small and 40 or (compact and 54 or 72)
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

    local chronoY = y + frameH + (small and 3 or (compact and 7 or 9))
    local chronoFont = small and FONT_L or (compact and FONT_XL or FONT_XXL)
    drawCentered(cx, chronoY, chrono, chronoFont, palette.textColor)
    lcd.font(chronoFont)
    local _, chronoValueH = lcd.getTextSize(chrono)
    return chronoY + chronoValueH
end

local function drawGib2aLogo(centerX, y, compact, small)
    if gib2aLogo == nil or not lcd.drawBitmap then
        return
    end

    local logoW = small and GIB2A_LOGO_SMALL_WIDTH
        or (compact and GIB2A_LOGO_COMPACT_WIDTH or GIB2A_LOGO_WIDTH)
    local logoH = small and GIB2A_LOGO_SMALL_HEIGHT
        or (compact and GIB2A_LOGO_COMPACT_HEIGHT or GIB2A_LOGO_HEIGHT)
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
    local yellow = lcd.RGB(255, 210, 0)
    local orange = lcd.RGB(255, 110, 0)
    for i = 0, 23 do
        local fromP, midP = maxPercent * i / 24, maxPercent * (i + 0.5) / 24
        local color = palette.bgGaugeColor
        if active > fromP then
            if midP < maxPercent * 0.62 then color = palette.safeColor
            elseif midP < maxPercent * 0.78 then color = yellow
            elseif midP < maxPercent * 0.91 then color = orange
            else color = palette.criticalColor end
        end
        if lcd.drawAnnulusSector then
            lcd.color(color)
            lcd.drawAnnulusSector(cx, cy, inner, radius,
                210 + 300 * i / 24, 210 + 300 * (i + 0.82) / 24)
        end
    end
end

local GAUGE_VALUE_FONTS = {
    FONT_XXL, FONT_XL, FONT_L, FONT_STD, FONT_XS, FONT_XXS
}

local function fitGaugeValueFont(text, maxWidth, maxHeight, firstFont)
    local fallback = GAUGE_VALUE_FONTS[#GAUGE_VALUE_FONTS]
    for i = firstFont, #GAUGE_VALUE_FONTS do
        local font = GAUGE_VALUE_FONTS[i]
        lcd.font(font)
        local textW, textH = lcd.getTextSize(text)
        if textW <= maxWidth and textH <= maxHeight then
            return font, textW, textH
        end
    end

    lcd.font(fallback)
    local textW, textH = lcd.getTextSize(text)
    return fallback, textW, textH
end

local function drawMainGauge(cx, cy, radius, value, label, unit, percent, palette, compact)
    drawSegmentedGauge(cx, cy, radius, percent, 110, palette)
    local labelY = unit ~= "" and (cy + (compact and 3 or 6))
        or (cy + (compact and 8 or 14))
    local innerRadius = radius - math.max(5, math.floor(radius * 0.13))
    local valueGap = 3
    local maxValueWidth = math.max(1, innerRadius * 2 - 8)
    local maxValueHeight = math.max(1,
        labelY - valueGap - (cy - innerRadius))
    local valueFont, valueW, valueH = fitGaugeValueFont(
        value, maxValueWidth, maxValueHeight, compact and 2 or 1)
    local valueY = labelY - valueH - valueGap
    lcd.font(valueFont)
    lcd.color(palette.textColor)
    lcd.drawText(math.floor(cx - valueW / 2), math.floor(valueY), value, 0)
    drawCentered(cx, labelY, label,
        compact and FONT_XS or FONT_STD, palette.textColor)
    if unit ~= "" then
        drawCentered(cx, cy + (compact and 16 or 24), unit,
            compact and FONT_XXS or FONT_XS, palette.gaugeColor)
    end
end

local function drawPumpGauge(cx, cy, radius, value, percent, palette, compact, label, maxPercent)
    label = label or "PUMP"
    drawSegmentedGauge(cx, cy, radius, percent, maxPercent or 100, palette)
    local labelY = cy + (compact and 4 or 6)
    local innerRadius = radius - math.max(5, math.floor(radius * 0.13))
    local valueGap = 3
    local maxValueWidth = math.max(1, innerRadius * 2 - 8)
    local maxValueHeight = math.max(1,
        labelY - valueGap - (cy - innerRadius))
    local valueFont, valueW, valueH = fitGaugeValueFont(
        value, maxValueWidth, maxValueHeight, compact and 3 or 2)
    local valueY = labelY - valueH - valueGap
    lcd.font(valueFont)
    lcd.color(palette.textColor)
    lcd.drawText(math.floor(cx - valueW / 2), math.floor(valueY), value, 0)
    drawCentered(cx, labelY, label,
        compact and FONT_XXS or FONT_XS, palette.textColor)
end

local function drawFuelGauge(x, y, width, percent, value, palette, compact)
    local red = palette.criticalColor
    local yellow = lcd.RGB(255, 210, 0)
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
    drawActiveZone(50, 100, palette.safeColor)

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

local function getDashboardLayout(w, h)
    local margin = math.max(5, math.floor(w * 0.012))

    -- FULL keeps the validated 800x480 geometry unchanged.
    if w >= 700 and h >= 430 then
        local bigR = math.floor(math.min(w * 0.17, h * 0.25))
        return false, false, margin,
            math.floor(h * 0.58), bigR,
            math.floor(h * 0.65), math.floor(bigR * 0.59),
            math.floor(h * 0.89), true
    end

    local fuelY = h - 32
    local small = h < 300
    local pumpR
    local pumpY
    local gaugeTop
    local gaugeBottom

    if small then
        pumpR = math.max(18, math.floor(math.min(w * 0.055, h * 0.09)))
        pumpY = fuelY - pumpR - 20
        gaugeTop = 100
        gaugeBottom = pumpY - pumpR - 4
    else
        pumpR = math.max(24, math.floor(math.min(w * 0.075, h * 0.10)))
        pumpY = fuelY - pumpR - 22
        gaugeTop = 115
        gaugeBottom = pumpY - pumpR - 5
    end

    local availableGaugeHeight = math.max(2, gaugeBottom - gaugeTop)
    local bigR = math.floor(math.min(
        w * (small and 0.105 or 0.13),
        availableGaugeHeight / 2
    ))
    if not small and w >= 600 then
        -- MEDIUM large: use the extra X14-class space without fixed pixels.
        bigR = math.floor(math.min(w * 0.115625, h * 0.20556))
        pumpR = math.floor(math.min(w * 0.078125, h * 0.13889))
    end
    local gaugeY = math.floor((gaugeTop + gaugeBottom) / 2)
    if not small then
        -- MEDIUM: align the three gauges lower and free the side panels.
        gaugeY = math.floor(h * 0.63)
        pumpY = gaugeY
    end
    local showPanels = (not small) and w >= 600 and h >= 320

    return true, small, margin, gaugeY, bigR,
        pumpY, pumpR, fuelY, showPanels
end

local function paint(widget)
    local w, h = lcd.getWindowSize()
    local palette = getPalette(widget.theme or 0)
    lcd.color(palette.bgColor)
    lcd.drawFilledRectangle(0, 0, w, h)
    local compact, small, margin, gaugeY, bigR,
        pumpY, pumpR, fuelY, showPanels = getDashboardLayout(w, h)
    local centerX = math.floor(w / 2)
    local panelW = math.floor(w * 0.255)
    local panelAvailableHeight = math.max(1, gaugeY - bigR - margin - 2)

    local headerBottomY = drawStatusHeader(centerX, margin, getStatusText(widget.ecuType, widget.temp2Value),
        fmtTimeMMSS(widget.chronoValue), math.floor(w * (small and 0.46 or (compact and 0.38 or 0.40))),
        palette, compact, small)
    drawGib2aLogo(centerX, headerBottomY + (small and 1 or (compact and 3 or 5)), compact, small)

    if showPanels then
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
            local shaftLabel = widget.ecuType == 1 and "SHAFT" or "HELI/TP"
            rightRows[#rightRows + 1] = { shaftLabel, dashboardValue(widget.heliTpRpmValue), "RPM" }
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
    local pumpMax
    if widget.ecuType == 0 then
        pumpMax = XICOY_PUMP_RAW_MAX
    elseif widget.ecuType == 1 then
        pumpMax = widget.jetCatPumpMax or JETCAT_PUMP_DEFAULT_MAX
    else
        pumpMax = widget.pumpMax or 100
    end
    drawMainGauge(math.floor(w * 0.235), gaugeY, bigR, dashboardValue(rpm), "RPM", "",
        mapToPercentRaw(rpm, rpmMax), palette, compact)
    drawMainGauge(math.floor(w * 0.765), gaugeY, bigR, dashboardValue(egt), "EGT", "",
        mapToPercentRaw(egt, egtMax), palette, compact)
    local pumpDisplay = decodePumpDisplayValue(widget.ecuType, pumpRaw)
    local pumpText
    local pumpLabel = "PUMP"
    if widget.ecuType == 1 then
        pumpText = dashboardValue(pumpDisplay, 1)
        pumpLabel = "PUMP V"
    else
        pumpText = dashboardValue(pumpDisplay)
    end
    local pumpPercent
    local pumpGaugeMaxPercent = 100
    if widget.ecuType == 1 then
        pumpPercent = mapToPercentRaw(pumpRaw, pumpMax)
        pumpGaugeMaxPercent = 110
    else
        pumpPercent = clamp01(mapToPercentRaw(pumpRaw, pumpMax))
    end
    drawPumpGauge(centerX, pumpY, pumpR,
        pumpText, pumpPercent, palette, compact, pumpLabel,
        pumpGaugeMaxPercent)
    local fuelFlowGap = compact and 2 or 4
    if compact and not small and w >= 600 then
        fuelFlowGap = 16
    end
    drawFuelFlow(centerX, pumpY + pumpR + fuelFlowGap, widget, palette, compact)

    local fuelAreaX = margin
    local fuelAreaW = w - 2 * margin
    drawFuelGauge(fuelAreaX,
        fuelY, fuelAreaW, clamp01(widget._fuelPercent),
        dashboardValue(widget._fuelDisplayValue or widget.fuelValue), palette, compact)
end

local ECU_TELEMETRY_BINDING_FIELDS = {
    "rpmSource", "rpmValue",
    "heliTpRpmSource", "heliTpRpmValue",
    "ecuThrottleSource", "ecuThrottleValue",
    "temp1Source", "temp1Value",
    "temp2Source", "temp2Value",
    "adc3Source", "adc3Value",
    "adc4Source", "adc4Value",
    "fuelSource", "fuelValue",
    "ambTempSource", "ambTempValue",
    "pressSource", "pressValue",
    "altSource", "altValue",
    "fuelFlowSource", "fuelFlowValue",
    "serialSource", "serialValue",
    "battUsedSource", "battUsedValue",
    "engineTimeSource", "engineTimeValue",
    "pumpAmpSource", "pumpAmpValue",
    "engineCurrentSource", "engineCurrentValue",
    "fuelConsumptionSource", "fuelConsumptionValue",
}

local function clearEcuTelemetryBindings(widget)
    for i = 1, #ECU_TELEMETRY_BINDING_FIELDS, 2 do
        local srcField = ECU_TELEMETRY_BINDING_FIELDS[i]
        local valField = ECU_TELEMETRY_BINDING_FIELDS[i + 1]

        widget[srcField] = nil
        widget[valField] = nil

        if widget._normalizedTelemetrySources then
            widget._normalizedTelemetrySources[srcField] = nil
        end
        if widget._sourceRecoveryAt then
            widget._sourceRecoveryAt[srcField] = nil
        end
    end

    widget._fuelPercent = nil
    widget._fuelDisplayValue = nil
    widget._flameOutArmed = false
    widget._restartArmed = false
    widget._lastEcuStatus = nil
    widget._autoBindStatus = nil
end

local function changeXicoyTelemetryMode(widget, newMode)
    local oldMode = widget.telemetryMode or TELEMETRY_MODE_BASIC
    if widget.ecuType ~= 0 or oldMode == newMode then
        return false
    end

    clearEcuTelemetryBindings(widget)
    widget.telemetryMode = newMode
    return true
end

local function buildConfig(widget)
    local line
    local ecuChoices = {
        { "Xicoy",    1 }, -- ecuType 0
        { "JetCat",   2 }, -- ecuType 1
        { "Enjet",    6 }, -- ecuType 5
        { "Linton",   5 }, -- ecuType 4
        { "KingTech", 3 }, -- ecuType 2
        { "Swiwin",   4 }, -- ecuType 3
    }

    local themeChoices = {
        { "Standard",      1 },
        { "High contrast", 2 },
        { "Amber",         3 },
    }

    if widget.ecuType == 0 then
        -- Setup Mode
        local modeChoices = {
            { "Basic",    1 },
            { "Extended", 2 },
            { "Maximum",  3 },
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

                if changeXicoyTelemetryMode(widget, newMode) then
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

                if changeXicoyTelemetryMode(widget, newMode) then
                    if form.clear then
                        form.clear()
                        buildConfig(widget)
                    end
                end
            end

        )
        end
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
                    clearEcuTelemetryBindings(widget)
                    widget.ecuType = newType
                    if (not lcd.isVisible) or lcd.isVisible() then
                        lcd.invalidate()
                    end
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
                    clearEcuTelemetryBindings(widget)
                    widget.ecuType = t
                    if (not lcd.isVisible) or lcd.isVisible() then
                        lcd.invalidate()
                    end
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

    local heliTpRpmSensorLabel = widget.ecuType == 1
        and "Shaft RPM Sensor" or "Heli/TP RPM Sensor"
    line = form.addLine(heliTpRpmSensorLabel)
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

        line = form.addLine("Pump Flow Sensor")
        form.addSourceField(line, nil,
            function() return widget.fuelFlowSource end,
            function(v) widget.fuelFlowSource = v end)

        line = form.addLine("Fuel Consumption Sensor")
        form.addSourceField(line, nil,
            function() return widget.fuelConsumptionSource end,
            function(v) widget.fuelConsumptionSource = v end)

        line = form.addLine("Pressure Sensor")
        form.addSourceField(line, nil,
            function() return widget.pressSource end,
            function(v) widget.pressSource = v end)
    elseif widget.ecuType == 1 then
        line = form.addLine("ECU Current Sensor")
        form.addSourceField(line, nil,
            function() return widget.engineCurrentSource end,
            function(v) widget.engineCurrentSource = v end)

        line = form.addLine("Altitude Sensor")
        form.addSourceField(line, nil,
            function() return widget.altSource end,
            function(v) widget.altSource = v end)

        line = form.addLine("Fuel Flow Sensor")
        form.addSourceField(line, nil,
            function() return widget.fuelFlowSource end,
            function(v) widget.fuelFlowSource = v end)

        line = form.addLine("Battery Capacity Sensor")
        form.addSourceField(line, nil,
            function() return widget.battUsedSource end,
            function(v) widget.battUsedSource = v end)
    end

    -- Pump max (valeur réelle pour 100%)
    if widget.ecuType ~= 0 then
        local pumpMaxLabel = widget.ecuType == 1
            and "Pump Max Voltage (100%)" or "Pump Max (100%)"
        line = form.addLine(pumpMaxLabel)
        local pumpField
        if widget.ecuType == 1 then
            pumpField = form.addNumberField(line, nil, 1, 1000,
                function()
                    return math.floor(
                        (widget.jetCatPumpMax or JETCAT_PUMP_DEFAULT_MAX) * 10
                        + 0.5
                    )
                end,
                function(v) widget.jetCatPumpMax = v / 10 end)
            if pumpField and pumpField.default then
                pumpField:default(17)
            end
            if pumpField and pumpField.decimals then
                pumpField:decimals(1)
            end
            if pumpField and pumpField.suffix then
                pumpField:suffix("V")
            end
            if pumpField and pumpField.step then
                pumpField:step(1)
            end
        else
            pumpField = form.addNumberField(line, nil, 1, 1000,
                function() return widget.pumpMax or 100 end,
                function(v) widget.pumpMax = v end)
            if pumpField and pumpField.step then
                pumpField:step(1)
            end
        end
    end

    -- Fuel remaining (valeur réelle)
    local fuelSensorLabel = "Fuel Sensor (Real)"
    if widget.ecuType == 0 or widget.ecuType == 1 then
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

                if fuelChanged then
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
    if widget.ecuType == 0 and mode ~= TELEMETRY_MODE_BASIC then
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
                    if (not lcd.isVisible) or lcd.isVisible() then
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
                    if (not lcd.isVisible) or lcd.isVisible() then
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

local WAKEUP_CORE_FIELDS = {
    "chronoSource", "chronoValue",
    "rpmSource", "rpmValue",
    "heliTpRpmSource", "heliTpRpmValue",
    "ecuThrottleSource", "ecuThrottleValue",
    "temp1Source", "temp1Value",
    "temp2Source", "temp2Value",
    "adc3Source", "adc3Value",
    "adc4Source", "adc4Value",
    "diy1Source", "diy1Value",
    "diy2Source", "diy2Value",
    "diy3Source", "diy3Value",
}

local WAKEUP_EXTENDED_FIELDS = {
    "ambTempSource", "ambTempValue",
    "pressSource", "pressValue",
    "altSource", "altValue",
    "fuelFlowSource", "fuelFlowValue",
    "serialSource", "serialValue",
    "battUsedSource", "battUsedValue",
    "engineTimeSource", "engineTimeValue",
    "pumpAmpSource", "pumpAmpValue",
    "engineCurrentSource", "engineCurrentValue",
    "fuelConsumptionSource", "fuelConsumptionValue",
}

local WAKEUP_SYSTEM_FIELDS = {
    "rxbattSource", "rxbattValue",
    "rssi1Source", "rssi1Value",
    "rssi2Source", "rssi2Value",
}

local function wakeup(widget)
    -- Use a dirty flag so lcd.invalidate() is only called once per wakeup loop
    -- as suggested by Rob Thomson.
    local dirty = false

    for i = 1, #WAKEUP_CORE_FIELDS, 2 do
        dirty = updateField(
            widget,
            WAKEUP_CORE_FIELDS[i],
            WAKEUP_CORE_FIELDS[i + 1]
        ) or dirty
    end
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
    for i = 1, #WAKEUP_EXTENDED_FIELDS, 2 do
        dirty = updateField(
            widget,
            WAKEUP_EXTENDED_FIELDS[i],
            WAKEUP_EXTENDED_FIELDS[i + 1]
        ) or dirty
    end

    -- Capteurs généraux
    for i = 1, #WAKEUP_SYSTEM_FIELDS, 2 do
        dirty = updateSystemField(
            widget,
            WAKEUP_SYSTEM_FIELDS[i],
            WAKEUP_SYSTEM_FIELDS[i + 1]
        ) or dirty
    end
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

    if dirty then
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

local function readStandardParams(widget, firstIndex, lastIndex)
    for i = firstIndex, lastIndex do
        local param = PERSISTENCE_PARAMS[i]
        local value = storage.read(param.key)

        if value == nil then
            value = param.default
        end

        widget[param.key] = value
    end
end

local function read(widget)
    readStandardParams(widget, 1, 33)

    local fuelMax = storage.read("fuelMax")
    readStandardParams(widget, 34, 34)
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

    readStandardParams(widget, 35, 35)

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

    readStandardParams(widget, 36, 37)

    local storedJetCatPumpMax = storage.read("jetCatPumpMax")
    if type(storedJetCatPumpMax) == "number" and storedJetCatPumpMax > 0 then
        widget.jetCatPumpMax = storedJetCatPumpMax
    else
        widget.jetCatPumpMax = JETCAT_PUMP_DEFAULT_MAX
    end

end

local function writeStandardParams(widget, firstIndex, lastIndex)
    for i = firstIndex, lastIndex do
        local param = PERSISTENCE_PARAMS[i]
        storage.write(param.key, widget[param.key])
    end
end

local function write(widget)
    writeStandardParams(widget, 1, 33)
    storage.write("fuelMax",          widget.fuelMax)
    writeStandardParams(widget, 34, 34)
    storage.write(
        "telemetryMode",
        widget.telemetryMode or TELEMETRY_MODE_BASIC
    )
    storage.write("setupModeSchema", SETUP_MODE_SCHEMA)
    storage.write("ecuType", widget.ecuType or 0)
    writeStandardParams(widget, 35, 35)
    storage.write("xicoyFuelStartPercent", widget.xicoyFuelStartPercent or 100)
    storage.write(
        "fuelColorSoundAlertsEnabled",
        widget.fuelColorSoundAlertsEnabled ~= false
    )
    writeStandardParams(widget, 36, 37)
    storage.write(
        "jetCatPumpMax",
        widget.jetCatPumpMax or JETCAT_PUMP_DEFAULT_MAX
    )
end

-------------------------------------------------------------
-- Enregistrement du widget
-------------------------------------------------------------

local function init()
    loadGib2aLogo()
    system.registerWidget({
        key        = "GIB2A",
			name       = "GIB2A TURBINE Widjet V" .. WIDGET_VERSION,
        create     = create,
        wakeup     = wakeup,
        configure  = configure,
        paint      = paint,
        read       = read,
        write      = write
    })
end

return { init = init }
