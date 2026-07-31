-- GIBA - Xicoy ProHUb - V1.1  Corsica fly dream
-- Télémétrie Xicoy + menu de configuration
-- Valeurs réelles (RPM, EGT, Pump, Fuel)
-- Zones rouges : EGT > 700°C, RPM > 100% jusqu'à 110%
-- Texte en blanc, titre + sous-titre + signature

---@diagnostic disable: undefined-global

local audioPath = system.getAudioVoice() or "/audio"

-------------------------------------------------------------
-- Création / mise à jour du widget
-------------------------------------------------------------

local function create(zone, options)
    return {
        zone    = zone,
        options = options,

        -- Chrono (timer ETHOS ou autre source temps)
        chronoSource   = nil, chronoValue   = nil,

        -- Capteurs Xicoy / ETHOS
        rpmSource      = nil, rpmValue      = nil,   -- RPM Sensor
        temp1Source    = nil, temp1Value    = nil,   -- Temp 1 (EGT)
        temp2Source    = nil, temp2Value    = nil,   -- Temp 2 (Status code)
        adc3Source     = nil, adc3Value     = nil,   -- ADC3 (ECU V)
        adc4Source     = nil, adc4Value     = nil,   -- ADC4 (Pump command / volt)

        fuelSource               = nil, fuelValue             = nil,   -- Fuel remaining (valeur réelle)
        fuelAlertPercent         = 25,                        -- Seuil alarme (% restant)
        fuelCriticalAlertPercent = 5,                         -- Seuil alarme critique (% restant)
        fuelAlertFile            = nil,                       -- Son alarme fuel (seuil)
        fuelCriticalAlertFile    = nil,                       -- Son alarme fuel critique
        _fuelPercent             = nil,                       -- valeur interne %% (calculée)
        fuelMax                  = 100,                       -- Basic : 100%% = plein (Xicoy Fuel %)

        -- DIY Xicoy / capteurs libres
        diy1Source     = nil, diy1Value     = nil,   -- DIY1 (optionnel)
        diy2Source     = nil, diy2Value     = nil,   -- DIY2
        diy3Source     = nil, diy3Value     = nil,   -- DIY3

        -- Mode Xicoy Extended / Maximum (ProHub)
        ambTempSource      = nil, ambTempValue      = nil,   -- Ambient Temp (°C)
        pressSource        = nil, pressValue        = nil,   -- Pressure (mBar)
        altSource          = nil, altValue          = nil,   -- Altitude (m)
        fuelFlowSource     = nil, fuelFlowValue     = nil,   -- Fuel Flow (ml/min)
        serialSource       = nil, serialValue       = nil,   -- Serial Number
        battUsedSource     = nil, battUsedValue     = nil,   -- Battery Used (mAh)
        engineTimeSource   = nil, engineTimeValue   = nil,   -- Engine Time (s)
        pumpAmpSource      = nil, pumpAmpValue      = nil,   -- Pump Amperage (0.1A)

        -- Capteur général (RxBatt)
        rxbattSource   = nil, rxbattValue   = nil,   -- RxBatt Sensor

        -- RSSI
        rssi1Source    = nil, rssi1Value    = nil,   -- RSSI Sensor 1 (2.4G)
        rssi2Source    = nil, rssi2Value    = nil,   -- RSSI Sensor 2 (900M)

        -- Échelles max pour les jauges (valeurs réelles)
        rpmMax         = 160000,                     -- RPM max turbine (100%%)
        egtMax         = 900,                        -- EGT max (°C)
        pumpMax        = 100,                        -- Valeur max Pump
        telemetryMode  = 0,                          -- 0=Basic, 1=Advanced/Expert (ProHub Extended)
        ecuType        = 0,                          -- 0=Xicoy, 1=JetCat, 2=KingTech, 3=Swiwin (ECU status decode)
        theme          = 0,                          -- 0=Std, 1=High contrast, 2=Amber
    }
end

-------------------------------------------------------------
-- Table des messages ECU Xicoy (codes 0 à 36)
-------------------------------------------------------------

local msg_table_Xicoy = {
    [0]  = "HighTemp",
    [1]  = "Trim Low",
    [2]  = "SetIdle",
    [3]  = "Ready",
    [4]  = "Ignition",
    [5]  = "PreHeat",
    [6]  = "Fuel Ramp",
    [7]  = "Fuel Ignit",
    [8]  = "Fuel Delay",
    [9]  = "RPM Ramp",
    [10] = "Set Slow",
    [11] = "Set High",
    [12] = "Learn LO",
    [13] = "Learn HI",
    [14] = "Start On",
    [15] = "Start On",
    [16] = "UserOff",
    [17] = "Failsafe",
    [18] = "Low RPM",
    [19] = "Reset",
    [20] = "RXPwFail",
    [21] = "PreHeat",
    [22] = "Battery",
    [23] = "Time Out",
    [24] = "Overload",
    [25] = "Ign.Fail",
    [26] = "Burner On",
    [27] = "Starting",
    [28] = "SwitchOv",
    [29] = "Cal.Pump",
    [30] = "PumpLimi",
    [31] = "Wait DS",
    [32] = "PwrBoost",
    [33] = "Run-Idle",
    [34] = "Run-Max",
    [35] = "Restart",
    [36] = "No Status",
}

-------------------------------------------------------------
-- Tables des statuts ECU (multi-marques)
--  - Xicoy : codes 0..36 (table ci-dessus)
--  - JetCat : codes 1..19 (Running) + 100..122 (Last Shutdown)
--  - KingTech / Swiwin : à compléter (table fournie par l'utilisateur)
-------------------------------------------------------------

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
    end

    return "Code " .. tostring(code)
end


-------------------------------------------------------------
-- Helper : lecture robuste d'une Source ETHOS
-------------------------------------------------------------

local function readSourceValue(src)
    if not src then
        return nil
    end

    local realSrc = src
    if type(src.name) == "function" then
        local n = src:name()
        if n and n ~= "" then
            local s2 = system.getSource(n)
            if s2 then
                realSrc = s2
            end
        end
    end

    if type(realSrc.value) == "function" then
        return realSrc:value()
    end
    return nil
end

-------------------------------------------------------------
-- Fuel : calcul du pourcentage + alarme à partir d'une valeur réelle
-------------------------------------------------------------

local function updateFuel(widget)
    -- Mode Basic Xicoy : fuelValue est déjà un pourcentage (0..100)
    local value       = widget.fuelValue     -- valeur % Xicoy
    local prevPercent = widget._fuelPercent
    local percent     = nil

    if type(value) == "number" then
        percent = value
        if percent < 0 then
            percent = 0
        elseif percent > 100 then
            percent = 100
        end
    end

    widget._fuelPercent = percent

    local alert    = widget.fuelAlertPercent or 0
    local critical = widget.fuelCriticalAlertPercent or 0

    -- Alarme critique : fuel très bas (seuil critique)
    if percent and critical > 0 and percent <= critical then
        if (prevPercent == nil) or (prevPercent > critical) then
            if system.playHaptic then
                system.playHaptic(500)
            end
            if widget.fuelCriticalAlertFile and widget.fuelCriticalAlertFile ~= "" and system.playFile then
                if audioPath then
                    system.playFile(audioPath .. "/" .. widget.fuelCriticalAlertFile)
                else
                    system.playFile(widget.fuelCriticalAlertFile)
                end
            end
            if system.playNumber and UNIT_PERCENT then
                system.playNumber(math.floor(percent + 0.5), UNIT_PERCENT, 0)
            end
        end
        return
    end

    -- Alarme seuil fuel (non critique)
    if percent and alert > 0 and percent <= alert then
        if (prevPercent == nil) or (prevPercent > alert) then
            -- Alarme : vibration + son + annonce vocale du pourcentage restant
            if system.playHaptic then
                system.playHaptic(300)
            end
            if widget.fuelAlertFile and widget.fuelAlertFile ~= "" and system.playFile then
                if audioPath then
                    system.playFile(audioPath .. "/" .. widget.fuelAlertFile)
                else
                    system.playFile(widget.fuelAlertFile)
                end
            end
            if system.playNumber and UNIT_PERCENT then
                system.playNumber(math.floor(percent + 0.5), UNIT_PERCENT, 0)
            end
        end
    end
end


-------------------------------------------------------------
-- Helpers graphiques
-------------------------------------------------------------

local function getMainColor()
    -- Couleur principale FIXE : vert, indépendamment du thème ETHOS
    if lcd.RGB then
        return lcd.RGB(0, 160, 0)
    end
    -- Écrans N&B : on reste sur une valeur non nulle (gris clair)
    if lcd.GREY then
        return lcd.GREY(10)
    end
    return 1
end

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
local function getAlertColor()
    if lcd.RGB then
        return lcd.RGB(255, 0, 0)
    end
    return getGrey(30)
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

-- Jauge avec bande d'alerte : partie basse en colorNormal,
-- au-delà de bandStartPercent en colorAlert.
local function drawArcGaugeBand(cx, cy, innerR, outerR, startAngle, endAngle,
                                percent, bandStartPercent, colorNormal, colorAlert, colorBg)
    if percent == nil then percent = 0 end
    if percent < 0 then percent = 0 elseif percent > 110 then percent = 110 end  -- RPM peut aller à 110%
    if bandStartPercent == nil then bandStartPercent = 101 end

    if lcd.drawAnnulusSector == nil then
        lcd.color(colorBg)
        lcd.drawCircle(cx, cy, outerR)
        lcd.drawCircle(cx, cy, innerR)
        return
    end

    local sweep = endAngle - startAngle
    lcd.color(colorBg)
    lcd.drawAnnulusSector(cx, cy, innerR, outerR, startAngle, endAngle)

    if percent <= 0 then return end

    local p1 = math.min(percent, bandStartPercent)

    -- Partie normale
    if p1 > 0 then
        local end1 = startAngle + sweep * p1 / 100
        lcd.color(colorNormal)
        lcd.drawAnnulusSector(cx, cy, innerR, outerR, startAngle, end1)
    end

    -- Partie alerte
    if percent > bandStartPercent then
        local start2 = startAngle + sweep * bandStartPercent / 100
        local end2   = startAngle + sweep * percent / 100
        lcd.color(colorAlert)
        lcd.drawAnnulusSector(cx, cy, innerR, outerR, start2, end2)
    end
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
local function renderDashboard(widget, ctx)
    for _, o in ipairs(dashboardObjects) do
        if o.id == "rpm" and o.kind == "arcBand" then
            -- RPM : demi-jauge haut droite
            drawArcGaugeBand(
                ctx.cxRight, ctx.cyTop,
                ctx.innerBig, ctx.radiusBig,
                270, 450,
                ctx.rpmPercent or 0,
                100, -- bande rouge à partir de 100 %
                ctx.gaugeColor, ctx.alertColor, ctx.bgGaugeColor
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
            local lw, lh = lcd.getTextSize(label)
            local rpmLabelY = rpmValueY + th + 2
            lcd.drawText(ctx.cxRight - lw / 2, rpmLabelY, label, 0)

        elseif o.id == "egt" and o.kind == "arcBand" then
            -- EGT : demi-jauge bas droite
            local percent = ctx.egtPercent or 0
            local bandStart = ctx.egtBandStartPercent or 101

            drawArcGaugeBand(
                ctx.cxRight, ctx.cyBottom,
                ctx.innerBig, ctx.radiusBig,
                270, 450,
                percent,
                bandStart,
                ctx.gaugeColor, ctx.alertColor, ctx.bgGaugeColor
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
            local lw, lh = lcd.getTextSize(label)
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
            local lw, lh = lcd.getTextSize(label)
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
                if p <= 25 and lcd.RGB then
                    lcd.color(lcd.RGB(255, 0, 0))
                elseif p <= 50 and lcd.RGB then
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

local function paint(widget)
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

    -- Valeurs réelles
    local rpmValue  = (type(widget.rpmValue)   == "number") and widget.rpmValue   or nil
    local egtValue  = (type(widget.temp1Value) == "number") and widget.temp1Value or nil
    local pumpValue = (type(widget.adc4Value)  == "number") and widget.adc4Value  or nil
    local fuelValue = (type(widget.fuelValue)  == "number") and widget.fuelValue  or nil

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

    -- Sécuriser egtMax : si valeur absurde (nil ou trop basse), on repasse à 900°C par défaut
    local egtMax = widget.egtMax or 900
    if egtMax < 200 then
        egtMax = 900
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
    local pumpPercent = clamp01(mapToPercentRaw(pumpValue, widget.pumpMax or 0))
    local fuelPercent = clamp01(widget._fuelPercent)

    -- Texte affiché = VALEURS RÉELLES (sans %)
    local rpmText  = rpmValue  and string.format("%d", math.floor(rpmValue + 0.5))   or "--"
    local egtText  = egtValue  and string.format("%d", math.floor(egtValue + 0.5))   or "--"
    local pumpText = pumpValue and string.format("%d", math.floor(pumpValue + 0.5))  or "--"
    local fuelText = fuelValue and string.format("%d", math.floor(fuelValue + 0.5))  or "--"

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
	local function appendUnit(text, src)
		if not text or text == "--" or text == "" or not src then return text end
		if src.stringUnit then
			local u = src:stringUnit()
			if type(u) == "string" then
				u = u:gsub("^%s+", ""):gsub("%s+$", "")
				if u ~= "" then
					return text .. u
				end
			end
		end
		return text
	end

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
    -- 0) Signature en haut
    --------------------------------------------------------
    -- Signature en vert (couleur GIB2A)
    lcd.color(gaugeColor)
    lcd.font(FONT_STD)
    local sig = "Gib2a"
    local twSig, thSig = lcd.getTextSize(sig)
    local sigX = w - margin - twSig
    local sigY = 2
    lcd.drawText(sigX, sigY, sig, 0)

    --------------------------------------------------------
    -- 1) CHRONO (haut gauche)
    --------------------------------------------------------
    local chronoX = margin
    local chronoY = 2

    lcd.color(textColor)
    lcd.font(FONT_XXL)
    local tw, th = lcd.getTextSize(chronoText)
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
    local lw, lh = lcd.getTextSize(statusLine)

    -- Label en blanc, valeur de statut en vert
    lcd.color(textColor)
    lcd.drawText(statusX, statusY, statusLabel, 0)

    local labelW, _ = lcd.getTextSize(statusLabel)
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
        local lw1, _ = lcd.getTextSize(rssi1Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw1 + 5, yText, rssi1Value or "", 0)
        yText = yText + lineH + lineGap
    end
    if rssi2Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, rssi2Label, 0)
        local lw2, _ = lcd.getTextSize(rssi2Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw2 + 5, yText, rssi2Value or "", 0)
        yText = yText + lineH + lineGap
    end
    if rxBattLabel then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, rxBattLabel, 0)
        local lw3, _ = lcd.getTextSize(rxBattLabel)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw3 + 5, yText, rxBattValue or "", 0)
        yText = yText + lineH + lineGap
    end
    if ecuVLabel then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, ecuVLabel, 0)
        local lwE, _ = lcd.getTextSize(ecuVLabel)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lwE + 5, yText, ecuVValue or "", 0)
        yText = yText + lineH + lineGap
    end

    -- DIY1 / DIY2 / DIY3 sur la colonne de gauche (sous RxBatt / RSSI)
    if diy1Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, diy1Label, 0)
        local lw4, _ = lcd.getTextSize(diy1Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw4 + 5, yText, diy1Text or "", 0)
        yText = yText + lineH + lineGap
    end
    if diy2Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, diy2Label, 0)
        local lw5, _ = lcd.getTextSize(diy2Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw5 + 5, yText, diy2Text or "", 0)
        yText = yText + lineH + lineGap
    end
    if diy3Label then
        lcd.color(textColor)
        lcd.drawText(statusX, yText, diy3Label, 0)
        local lw6, _ = lcd.getTextSize(diy3Label)
        lcd.color(gaugeColor)
        lcd.drawText(statusX + lw6 + 5, yText, diy3Text or "", 0)
        yText = yText + lineH + lineGap
    end

    --------------------------------------------------------
    -- Expert (Extended/Maximum) : affichage des capteurs sous la liste de gauche
    --------------------------------------------------------
    if widget.telemetryMode == 1 then
        local function fmtTimeMMSS(v)
            if type(v) ~= "number" then return "--" end
            local total = math.floor(math.abs(v))
            local m = math.floor(total / 60)
            local s = total % 60
            local t = string.format("%d:%02d", m, s)
            if v < 0 then t = "-" .. t end
            return t
        end
        local function drawKV(label, value, unit)
            if not label then return end
            -- stop if there is no more vertical room
            if (yText + lineH) > (h - margin - 2) then return end

            -- Label
            lcd.color(textColor)
            lcd.font(FONT_STD)
            lcd.drawText(statusX, yText, label, 0)
            local lw, _ = lcd.getTextSize(label)

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
        if widget.ambTempSource then
            if type(widget.ambTempValue) == "number" then
                drawKV("Amb.T :", string.format("%.1f", widget.ambTempValue), "°C")
            else
                drawKV("Amb.T :", "--")
            end
        end
        if widget.pressSource then
            if type(widget.pressValue) == "number" then
                drawKV("Pres :", string.format("%d", math.floor(widget.pressValue + 0.5)), "mbar")
            else
                drawKV("Pres :", "--")
            end
        end
        if widget.altSource then
            if type(widget.altValue) == "number" then
                drawKV("Alt :", string.format("%d", math.floor(widget.altValue + 0.5)), "m")
            else
                drawKV("Alt :", "--")
            end
        end
        if widget.pumpAmpSource then
            if type(widget.pumpAmpValue) == "number" then
                drawKV("P.Amp :", string.format("%.1f", widget.pumpAmpValue), "A")
            else
                drawKV("P.Amp :", "--")
            end
        end
        if widget.battUsedSource then
            if type(widget.battUsedValue) == "number" then
                drawKV("Batt.Us :", string.format("%d", math.floor(widget.battUsedValue + 0.5)), "mAh")
            else
                drawKV("Batt.Us :", "--")
            end
        end
        if widget.engineTimeSource then
            drawKV("Eng.Tm :", fmtTimeMMSS(widget.engineTimeValue))
        end
        if widget.serialSource then
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
    -- Fuel Flow : affichage sous la jauge PUMP (Expert)
    --  - Centré sous la jauge
    --  - Maintenu au-dessus de la barre carburant pour éviter chevauchement
    --------------------------------------------------------
    if widget.telemetryMode == 1 and widget.fuelFlowSource then
        -- Texte
        local flowLabel = "Fuel.Fw"
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

local function buildConfig(widget)
    local line
    local ecuChoices = {
        { "Xicoy",    1 },
        { "JetCat",   2 },
        { "KingTech", 3 },
        { "Swiwin",   4 },
    }

    -- Setup Mode
    local modeChoices = {
        { "Basic",  1 },
        { "Expert", 2 },
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
                local m = widget.telemetryMode or 0
                if m < 0 then m = 0 elseif m > 1 then m = 1 end
                return m + 1
            end,
            
            function(v)
                local sel = v or 1
                if sel < 1 then sel = 1 elseif sel > #modeChoices then sel = #modeChoices end

                local newMode = sel - 1
                if newMode < 0 then newMode = 0 elseif newMode > 1 then newMode = 1 end

                if (widget.telemetryMode or 0) ~= newMode then
                    widget.telemetryMode = newMode
                    -- Rebuild form so Expert-only fields appear/disappear immediately
                    if form.clear then
                        form.clear()
                        buildConfig(widget)
                    end
                end
            end

        )
    else
        -- Fallback (older ETHOS): numeric selector
        form.addNumberField(line, nil, 0, 1,
            function() return widget.telemetryMode or 0 end,
            
            function(v)
                local newMode = v or 0
                if newMode < 0 then newMode = 0 elseif newMode > 1 then newMode = 1 end

                if (widget.telemetryMode or 0) ~= newMode then
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
                widget.ecuType = sel - 1
            end
        )
    else
        -- Fallback (older ETHOS): numeric selector (still stores 0..3 internally)
        local ecuField = form.addNumberField(line, nil, 0, (#ecuChoices - 1),
            function() return widget.ecuType or 0 end,
            function(v)
                local t = v or 0
                if t < 0 then t = 0 elseif t > (#ecuChoices - 1) then t = (#ecuChoices - 1) end
                widget.ecuType = t
            end
        )
        if ecuField and ecuField.step then
            ecuField:step(1)
        end
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
        function() return widget.egtMax or 900 end,
        function(v) widget.egtMax = v end)
    if egtField and egtField.suffix then
        egtField:suffix("C")
    end
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

    -- Pump max (valeur réelle pour 100%)
    line = form.addLine("Pump Max (100%)")
    local pumpField = form.addNumberField(line, nil, 1, 1000,
        function() return widget.pumpMax or 100 end,
        function(v) widget.pumpMax = v end)
    if pumpField and pumpField.step then
        pumpField:step(1)
    end

    -- Fuel remaining (valeur réelle)
    line = form.addLine("Fuel Sensor (Real)")
    form.addSourceField(line, nil,
        function() return widget.fuelSource end,
        function(v) widget.fuelSource = v end)

    -- Fuel max (valeur réelle)
    line = form.addLine("Fuel Max (Full)")
    local fuelMaxField = form.addNumberField(line, nil, 1, 50000,
        function() return widget.fuelMax or 100 end,
        function(v) widget.fuelMax = v end)
    if fuelMaxField and fuelMaxField.step then
        fuelMaxField:step(10)
    end

    -- Fuel alert threshold (% restant)
    line = form.addLine("Fuel Alert (%)")
    local fuelAlertField = form.addNumberField(line, nil, 0, 100,
        function() return widget.fuelAlertPercent or 0 end,
        function(v) widget.fuelAlertPercent = v end)
    if fuelAlertField and fuelAlertField.suffix then
        fuelAlertField:suffix("%")
    end
    
    if fuelAlertField and fuelAlertField.default then
        fuelAlertField:default(25)
    end
if fuelAlertField and fuelAlertField.step then
        fuelAlertField:step(1)
    end

    -- Fuel critical alert threshold (% restant)
    line = form.addLine("Fuel Critical Alert (%)")
    local fuelCriticalField = form.addNumberField(line, nil, 0, 100,
        function() return widget.fuelCriticalAlertPercent or 0 end,
        function(v) widget.fuelCriticalAlertPercent = v end)
    if fuelCriticalField and fuelCriticalField.suffix then
        fuelCriticalField:suffix("%")
    end
    
    if fuelCriticalField and fuelCriticalField.default then
        fuelCriticalField:default(5)
    end
if fuelCriticalField and fuelCriticalField.step then
        fuelCriticalField:step(1)
    end

    -- Fuel alert sound (seuil)
    line = form.addLine("Fuel Alert Sound")
    form.addFileField(line, nil, audioPath, "audio +ext",
        function() return widget.fuelAlertFile end,
        function(v) widget.fuelAlertFile = v end)

    -- Fuel critical alert sound (0% / très bas)
    line = form.addLine("Fuel Critical Sound")
    form.addFileField(line, nil, audioPath, "audio +ext",
        function() return widget.fuelCriticalAlertFile end,
        function(v) widget.fuelCriticalAlertFile = v end)


    -- Extended / Expert : télémétrie ProHub Extended / Maximum
    local mode = widget.telemetryMode or 0
    if mode == 1 then
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
                local n = v:name()
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
                local n = v:name()
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
                local n = v:name()
                if n == nil or n == "" then
                    widget.diy3Source = nil
                    return
                end
            end
            widget.diy3Source = v
        end)

    -- Capteur général (RxBatt)
    line = form.addLine("RxBatt Sensor")
    form.addSourceField(line, nil,
        function() return widget.rxbattSource end,
        function(v) widget.rxbattSource = v end)

    -- RSSI Sensor 1 / 2
    line = form.addLine("RSSI Sensor 1 (2.4G)")
    form.addSourceField(line, nil,
     function() return widget.rssi1Source end,
        function(v) widget.rssi1Source = v end)

    line = form.addLine("RSSI Sensor 2 (900M)")
    form.addSourceField(line, nil,
        function() return widget.rssi2Source end,
        function(v) widget.rssi2Source = v end)

    -- Chrono
    line = form.addLine("Chrono Source")
    form.addSourceField(line, nil,
        function() return widget.chronoSource end,
        function(v) widget.chronoSource = v end)


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
        widget.telemetryMode = 0
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

    local function updateField(srcField, valField)
        local src = widget[srcField]
        if src then
            local newValue = readSourceValue(src)
            if widget[valField] ~= newValue then
                widget[valField] = newValue
                dirty = true
            end
        end
    end

    updateField("chronoSource",   "chronoValue")

    updateField("rpmSource",      "rpmValue")
    updateField("temp1Source",    "temp1Value")
    updateField("temp2Source",    "temp2Value")
    updateField("adc3Source",     "adc3Value")
    updateField("adc4Source",     "adc4Value")

    updateField("diy1Source",     "diy1Value")
    updateField("diy2Source",     "diy2Value")
    updateField("diy3Source",     "diy3Value")

    -- ProHub Extended / Maximum
    updateField("ambTempSource",      "ambTempValue")
    updateField("pressSource",        "pressValue")
    updateField("altSource",          "altValue")
    updateField("fuelFlowSource",     "fuelFlowValue")
    updateField("serialSource",       "serialValue")
    updateField("battUsedSource",     "battUsedValue")
    updateField("engineTimeSource",   "engineTimeValue")
    updateField("pumpAmpSource",      "pumpAmpValue")

    -- Capteurs généraux
    updateField("rxbattSource",   "rxbattValue")

    updateField("rssi1Source",    "rssi1Value")
    updateField("rssi2Source",    "rssi2Value")

    -- Fuel (valeur réelle)
    updateField("fuelSource",     "fuelValue")
    updateFuel(widget)

    if dirty then
    if (not lcd.isVisible) or lcd.isVisible() then
        lcd.invalidate()
    end
end
end

local function update(widget)
    -- Toute la logique temps réel est déjà gérée dans wakeup()
end

local function backgroundProcessWidget(widgetToProcessInBackground)
    -- rien à faire en tâche de fond
end

-------------------------------------------------------------
-- Persistence (read / write)
-------------------------------------------------------------

local function read(widget)
    widget.chronoSource  = storage.read("chronoSource")

    widget.rpmSource      = storage.read("rpmSource")
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

    widget.rxbattSource   = storage.read("rxbattSource")

    widget.rssi1Source    = storage.read("rssi1Source")
    widget.rssi2Source    = storage.read("rssi2Source")

    local alert = storage.read("fuelAlertPercent")
    if alert ~= nil then
        -- Migration v1.1: ancien défaut 30% -> nouveau défaut 25%
        if alert == 30 then
            widget.fuelAlertPercent = 25
        else
            widget.fuelAlertPercent = alert
        end
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

    local rpmMax = storage.read("rpmMax")
    if rpmMax ~= nil then widget.rpmMax = rpmMax end

    local egtMax = storage.read("egtMax")
    if egtMax ~= nil then widget.egtMax = egtMax end

    local pumpMax = storage.read("pumpMax")
    if pumpMax ~= nil then widget.pumpMax = pumpMax end

    local fuelMax = storage.read("fuelMax")
    if fuelMax ~= nil then widget.fuelMax = fuelMax end
    -- Pour le mode Basic actuel, on force fuelMax dans une échelle 0..100
    if not widget.fuelMax or widget.fuelMax > 100 then
        widget.fuelMax = 100
    end

    local theme = storage.read("theme")
    if theme ~= nil then widget.theme = theme end

    local mode = storage.read("telemetryMode")
    if mode ~= nil then widget.telemetryMode = mode end

    local ecuType = storage.read("ecuType")
    if ecuType ~= nil then widget.ecuType = ecuType end
end

local function write(widget)
    storage.write("chronoSource",  widget.chronoSource)

    storage.write("rpmSource",      widget.rpmSource)
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

    storage.write("rxbattSource",   widget.rxbattSource)

    storage.write("rssi1Source",    widget.rssi1Source)
    storage.write("rssi2Source",    widget.rssi2Source)

    storage.write("fuelAlertPercent", widget.fuelAlertPercent)
    storage.write("fuelCriticalAlertPercent", widget.fuelCriticalAlertPercent)
    storage.write("fuelAlertFile",            widget.fuelAlertFile)
    storage.write("fuelCriticalAlertFile",    widget.fuelCriticalAlertFile)

    storage.write("rpmMax",           widget.rpmMax)
    storage.write("egtMax",           widget.egtMax)
    storage.write("pumpMax",          widget.pumpMax)
    storage.write("fuelMax",          widget.fuelMax)
    storage.write("theme",            widget.theme)
    storage.write("telemetryMode",    widget.telemetryMode or 0)
    storage.write("ecuType",          widget.ecuType or 0)
end

-------------------------------------------------------------
-- Enregistrement du widget
-------------------------------------------------------------

local function init()
    system.registerWidget({
        key        = "GIB2A",
			name       = "GIBA - Xicoy ProHUb - V1.1  Corsica fly dream",
        create     = create,
        update     = update,
        wakeup     = wakeup,
        configure  = configure,
        background = backgroundProcessWidget,
        paint      = paint,
        read       = read,
        write      = write
    })
end

return { init = init }
