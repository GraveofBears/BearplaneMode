local addonName, addon = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

BearplaneMode_Keybind = BearplaneMode_Keybind or ""
if BearplaneMode_FirstRun == nil then BearplaneMode_FirstRun = true end
BearplaneMode_FlightForm = BearplaneMode_FlightForm or "swift"

local configWindow, promptWindow
local pendingKey = nil
local isListening = false

-- State tracking
local lastIndoorState = nil
local lastSwimmingState = nil
local updateTimer = 0

-- ==========================================
-- TBC ZONE DETECTION ENGINE
-- ==========================================

local OUTLAND_ZONES = {
    ["Hellfire Peninsula"] = true,
    ["Zangarmarsh"] = true,
    ["Terokkar Forest"] = true,
    ["Nagrand"] = true,
    ["Blade's Edge Mountains"] = true,
    ["Shadowmoon Valley"] = true,
    ["Netherstorm"] = true,
    ["Shattrath City"] = true,
    ["Shattrath"] = true,
}

local TBC_DUNGEONS = {
    ["Hellfire Ramparts"] = true,
    ["The Blood Furnace"] = true,
    ["The Shattered Halls"] = true,
    ["The Botanica"] = true,
    ["The Mechanar"] = true,
    ["The Arcatraz"] = true,
    ["The Underbog"] = true,
    ["The Slave Pens"] = true,
    ["The Steamvault"] = true,
    ["Auchenai Crypts"] = true,
    ["Shadow Labyrinth"] = true,
    ["Sethekk Halls"] = true,
    ["Mana-Tombs"] = true,
    ["Karazhan"] = true,
}

local OUTDOOR_INSTANCES = {
    ["The Black Morass"] = true,
    ["Escape from Durnhold"] = true,
}

local INDOOR_SUBZONES = {
    ["Bank of Orgrimmar"] = true,
    ["Orgrimmar Innkeeper"] = true,
    ["Thrall's Throne Room"] = true,
    ["Hall of Legends"] = true,
    ["Orgrimmar Auction House"] = true,
    ["Orgrimmar Trade District"] = true,
}

local function DetectFormStrategy()
    local zone = GetZoneText()
    local subzone = GetSubZoneText()
    local indoors = IsIndoors()
    local swimming = IsSwimming()

    local strategy = "travel"

    if swimming then
        strategy = "aquatic"
    elseif OUTDOOR_INSTANCES[zone] then
        strategy = "travel"
    elseif indoors or TBC_DUNGEONS[zone] or TBC_DUNGEONS[subzone] or INDOOR_SUBZONES[subzone] then
        strategy = "cat"
    elseif OUTLAND_ZONES[zone] then
        strategy = "flight"
    end

    return strategy, zone
end

local function GenerateSmartMacro()
    local strategy, zone = DetectFormStrategy()
    local macro = "#showtooltip\n"

    if strategy == "aquatic" then
        macro = macro .. "/cancelform [stance:2,nocombat]\n"
        macro = macro .. "/cast [swimming] !Aquatic Form\n"
        macro = macro .. "/cast [noswimming] !Travel Form\n"

    elseif strategy == "flight" then
        local flightSpell = (BearplaneMode_FlightForm == "swift") and "Swift Flight Form" or "Flight Form"
        macro = macro .. "/cast [combat] Travel Form\n"
        macro = macro .. "/cancelform [nocombat]\n"
        macro = macro .. "/cast [nocombat,flyable,outdoors] " .. flightSpell .. "\n"

    elseif strategy == "cat" then
        macro = macro .. "/cancelform [stance:3,nocombat]\n"
        macro = macro .. "/cast !Cat Form\n"

    else
        macro = macro .. "/cancelform [stance:4,nocombat]\n"
        macro = macro .. "/cast !Travel Form\n"
    end

    return macro
end

-- ==========================================
-- SECURE BUTTON
-- ==========================================
local secureBtn = CreateFrame("Button", "BearplaneModeButton", UIParent, "SecureActionButtonTemplate")
secureBtn:RegisterForClicks("AnyDown", "AnyUp")
secureBtn:SetAttribute("type", "macro")
secureBtn:SetAttribute("macrotext*", "")

local function UpdateSecureButton()
    if InCombatLockdown() then return end
    local macroText = GenerateSmartMacro()
    secureBtn:SetAttribute("macrotext", macroText)
    secureBtn:SetAttribute("macrotext*", macroText)
end

frame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer + elapsed
    if updateTimer >= 0.1 then
        updateTimer = 0
        local currentIndoor = IsIndoors()
        local currentSwimming = IsSwimming()
        if currentIndoor ~= lastIndoorState or currentSwimming ~= lastSwimmingState then
            lastIndoorState = currentIndoor
            lastSwimmingState = currentSwimming
            UpdateSecureButton()
        end
    end
end)

-- ==========================================
-- KEYBIND (TBC Compatible)
-- ==========================================
local function ClearAllBearplaneBindings()
    ClearOverrideBindings(secureBtn)
end

local function ApplyBinding(key)
    if not key or key == "" then return end
    ClearAllBearplaneBindings()
    SetOverrideBindingClick(secureBtn, true, key, "BearplaneModeButton")
    BearplaneMode_Keybind = key
    if configWindow and configWindow.currentBindText then
        configWindow.currentBindText:SetText("Current Bind: |cff00ff00" .. key .. "|r")
    end
    print("|cff00ff00[Bearplane Mode]|r Bound to: " .. key)
end

local function RestoreBinding()
    if BearplaneMode_Keybind and BearplaneMode_Keybind ~= "" then
        ClearOverrideBindings(secureBtn)
        SetOverrideBindingClick(secureBtn, true, BearplaneMode_Keybind, "BearplaneModeButton")
    end
end

local function UnbindKey()
    if BearplaneMode_Keybind and BearplaneMode_Keybind ~= "" then
        ClearAllBearplaneBindings()
        BearplaneMode_Keybind = ""
        if configWindow and configWindow.currentBindText then
            configWindow.currentBindText:SetText("Current Bind: |cffff0000None|r")
        end
        print("|cff00ff00[Bearplane Mode]|r Hotkey unbound.")
    end
end

-- ==========================================
-- UI HELPERS
-- ==========================================

-- Creates a styled airline-look button (gold border, dark bg, white text)
local function CreateAirlineButton(parent, w, h, label)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, h)

    -- Dark background texture
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.06, 0.12, 0.95)

    -- Gold top border
    local borderTop = btn:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(0.85, 0.72, 0.30, 1)

    -- Gold bottom border
    local borderBot = btn:CreateTexture(nil, "BORDER")
    borderBot:SetHeight(1)
    borderBot:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    borderBot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    borderBot:SetColorTexture(0.85, 0.72, 0.30, 1)

    -- Gold left border
    local borderL = btn:CreateTexture(nil, "BORDER")
    borderL:SetWidth(1)
    borderL:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    borderL:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    borderL:SetColorTexture(0.85, 0.72, 0.30, 1)

    -- Gold right border
    local borderR = btn:CreateTexture(nil, "BORDER")
    borderR:SetWidth(1)
    borderR:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    borderR:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    borderR:SetColorTexture(0.85, 0.72, 0.30, 1)

    -- Button label
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetText(label)
    fs:SetTextColor(0.95, 0.88, 0.60)
    btn.label = fs

    btn:SetScript("OnEnter", function(self)
        bg:SetColorTexture(0.18, 0.14, 0.28, 0.98)
        fs:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        bg:SetColorTexture(0.08, 0.06, 0.12, 0.95)
        fs:SetTextColor(0.95, 0.88, 0.60)
    end)

    return btn
end

-- Creates a styled airline radio/checkbox
local function CreateAirlineCheck(parent, label)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(200, 26)

    local box = CreateFrame("Frame", nil, container)
    box:SetSize(16, 16)
    box:SetPoint("LEFT", container, "LEFT", 0, 0)

    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(0.06, 0.05, 0.10, 1)

    local boxBorder = box:CreateTexture(nil, "BORDER")
    boxBorder:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    boxBorder:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    boxBorder:SetColorTexture(0.85, 0.72, 0.30, 1)

    local innerBg = box:CreateTexture(nil, "ARTWORK")
    innerBg:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    innerBg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    innerBg:SetColorTexture(0.06, 0.05, 0.10, 1)
    box.innerBg = innerBg

    local checkMark = box:CreateTexture(nil, "OVERLAY")
    checkMark:SetSize(10, 10)
    checkMark:SetPoint("CENTER", box, "CENTER")
    checkMark:SetColorTexture(0.85, 0.72, 0.30, 1)
    checkMark:Hide()
    box.checkMark = checkMark

    local fs = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
    fs:SetText(label)
    fs:SetTextColor(0.85, 0.80, 0.65)

    container.box = box
    container._checked = false

    function container:SetChecked(val)
        self._checked = val
        if val then
            box.checkMark:Show()
            box.innerBg:SetColorTexture(0.15, 0.10, 0.05, 1)
            fs:SetTextColor(1, 0.95, 0.70)
        else
            box.checkMark:Hide()
            box.innerBg:SetColorTexture(0.06, 0.05, 0.10, 1)
            fs:SetTextColor(0.85, 0.80, 0.65)
        end
    end

    function container:GetChecked()
        return self._checked
    end

    container:EnableMouse(true)
    return container
end

-- Horizontal rule texture
local function AddDivider(parent, yOffset, anchorFrame)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", parent, "LEFT", 18, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -18, 0)
    if anchorFrame then
        line:SetPoint("TOP", anchorFrame, "BOTTOM", 0, yOffset)
    end
    line:SetColorTexture(0.85, 0.72, 0.30, 0.35)
    return line
end

-- ==========================================
-- PROMPT WINDOW (styled)
-- ==========================================
local function CreatePromptWindow()
    if promptWindow then return promptWindow end
    local pf = CreateFrame("Frame", "BearplanePromptFrame", UIParent, "BackdropTemplate")
    pf:SetSize(340, 160)
    pf:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    pf:SetFrameStrata("DIALOG")

    pf:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = false, tileSize = 32, edgeSize = 26,
        insets = { left = 9, right = 10, top = 10, bottom = 9 }
    })
    pf:SetBackdropColor(0.05, 0.04, 0.08, 0.97)
    pf:SetBackdropBorderColor(0.85, 0.72, 0.30, 0.90)

    -- Header stripe
    local stripe = pf:CreateTexture(nil, "BACKGROUND")
    stripe:SetHeight(28)
    stripe:SetPoint("TOPLEFT", pf, "TOPLEFT", 2, -2)
    stripe:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -2, -2)
    stripe:SetColorTexture(0.12, 0.09, 0.20, 1)

    local stripeText = pf:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    stripeText:SetPoint("TOP", pf, "TOP", 0, -12)
    stripeText:SetJustifyH("CENTER")
    stripeText:SetText("|cffD4AF37✦ BEARPLANE AIRLINES — CONFLICT DETECTED ✦|r")

    pf.text = pf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pf.text:SetPoint("TOP", stripeText, "BOTTOM", 0, -14)
    pf.text:SetWidth(280)
    pf.text:SetJustifyH("CENTER")

    local yesBtn = CreateAirlineButton(pf, 100, 28, "CONFIRM")
    yesBtn:SetPoint("BOTTOMLEFT", pf, "BOTTOMLEFT", 30, 20)
    yesBtn:SetScript("OnClick", function()
        if pendingKey then ApplyBinding(pendingKey); pendingKey = nil end
        pf:Hide()
    end)

    local noBtn = CreateAirlineButton(pf, 100, 28, "CANCEL")
    noBtn:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", -30, 20)
    noBtn:SetScript("OnClick", function()
        pendingKey = nil
        pf:Hide()
    end)

    pf:Hide()
    promptWindow = pf
    return promptWindow
end

local function ShowOverwritePrompt(key, currentAction)
    local pf = CreatePromptWindow()
    pendingKey = key
    pf.text:SetText(string.format("Key |cff00ffff%s|r is currently assigned to:\n|cffffd100%s|r\n\nOverwrite with Bearplane binding?", key, currentAction))
    pf:Show()
end

-- ==========================================
-- MAIN CONFIG WINDOW (Airline Style)
-- ==========================================
local function CreateConfigWindow()
    if configWindow then return configWindow end

    local f = CreateFrame("Frame", "BearplaneConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(380, 340)
    f:SetPoint("CENTER", UIParent, "CENTER")
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Main backdrop: near-black with gold border
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = false, tileSize = 32, edgeSize = 28,
        insets = { left = 10, right = 11, top = 11, bottom = 10 }
    })
    f:SetBackdropColor(0.05, 0.04, 0.09, 0.97)
    f:SetBackdropBorderColor(0.85, 0.72, 0.30, 0.95)

    -- ── Header band ──────────────────────────────────────
    local header = CreateFrame("Frame", nil, f)
    header:SetHeight(62)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    local headerBg = header:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAllPoints()
    headerBg:SetColorTexture(0.10, 0.07, 0.18, 1)

    -- Gold top stripe
    local headerLine = header:CreateTexture(nil, "BORDER")
    headerLine:SetHeight(2)
    headerLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerLine:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerLine:SetColorTexture(0.85, 0.72, 0.30, 0.9)

    -- BPM Logo (top-left corner of header)
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(80, 80)
    logo:SetPoint("LEFT", header, "LEFT", 10, 0)
    logo:SetTexture("Interface\\AddOns\\BearplaneMode\\BPMlogo")
    -- Fallback: show a colored box if logo not found
    logo:SetTexCoord(0, 1, 0, 1)

    -- BPM name & tagline (offset right of logo)
    local bpmodeName = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    bpmodeName:SetPoint("TOPLEFT", header, "TOPLEFT", 100, -12)
    bpmodeName:SetText("|cffD4AF37BEARPLANE MODE|r")

    local tagline = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tagline:SetPoint("TOPLEFT", bpmodeName, "BOTTOMLEFT", 0, -3)
    tagline:SetText("|cff9988bbSkybound · Seabound · Unbound|r")

    local version = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOPRIGHT", header, "TOPRIGHT", -10, -8)
    version:SetText("|cff665577v1.0.4|r")

    -- ── Keybind section ──────────────────────────────────
    local section1Label = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    section1Label:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 18, -14)
    section1Label:SetText("|cffD4AF37>>|r |cffccbbaaKEYBIND CONFIGURATION|r")

    -- Current bind highlighted box
    local bindBox = CreateFrame("Frame", nil, f, "BackdropTemplate")
    bindBox:SetSize(316, 30)
    bindBox:SetPoint("TOPLEFT", section1Label, "BOTTOMLEFT", 0, -8)
    bindBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bindBox:SetBackdropColor(0.06, 0.08, 0.04, 0.95)
    bindBox:SetBackdropBorderColor(0.85, 0.72, 0.30, 0.9)

    f.currentBindText = bindBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.currentBindText:SetPoint("CENTER", bindBox, "CENTER")
    f.currentBindText:SetJustifyH("CENTER")
    local bindDisplay = (BearplaneMode_Keybind ~= "" and "|cff00ff00" .. BearplaneMode_Keybind or "|cffff4444None") .. "|r"
    f.currentBindText:SetText("Current Bind:  " .. bindDisplay)

    local infoText = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", bindBox, "BOTTOMLEFT", 0, -6)
    infoText:SetText("|cff887799Click 'Bind New Key', then press your desired hotkey.|r")

    -- Bind / Unbind buttons side by side
    local bindBtn = CreateAirlineButton(f, 154, 30, "BIND NEW KEY")
    bindBtn:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -12)

    local unbindBtn = CreateAirlineButton(f, 154, 30, "UNBIND HOTKEY")
    unbindBtn:SetPoint("TOPLEFT", bindBtn, "TOPRIGHT", 8, 0)

    unbindBtn:SetScript("OnClick", function()
        UnbindKey()
        f.currentBindText:SetText("Current Bind: |cffff0000None|r")
    end)

    -- Divider
    local div1 = AddDivider(f, -10, bindBtn)

    -- ── Flight Form section ──────────────────────────────
    local section2Label = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    section2Label:SetPoint("TOP", div1, "BOTTOM", 0, -12)
    section2Label:SetJustifyH("CENTER")
    section2Label:SetText("|cffD4AF37>>|r |cffccbbaaFLIGHT FORM SELECTION|r")

    local swiftCheck = CreateAirlineCheck(f, "Swift Flight Form")
    swiftCheck:SetPoint("TOP", section2Label, "BOTTOM", 0, -10)
    swiftCheck:SetPoint("LEFT", f, "CENTER", -90, 0)

    local normalCheck = CreateAirlineCheck(f, "Flight Form")
    normalCheck:SetPoint("TOP", swiftCheck, "BOTTOM", 0, -6)
    normalCheck:SetPoint("LEFT", f, "CENTER", -90, 0)

    local function UpdateFlightChecks()
        swiftCheck:SetChecked(BearplaneMode_FlightForm == "swift")
        normalCheck:SetChecked(BearplaneMode_FlightForm == "normal")
    end
    UpdateFlightChecks()

    swiftCheck:SetScript("OnMouseDown", function()
        BearplaneMode_FlightForm = "swift"
        UpdateFlightChecks()
        UpdateSecureButton()
    end)

    normalCheck:SetScript("OnMouseDown", function()
        BearplaneMode_FlightForm = "normal"
        UpdateFlightChecks()
        UpdateSecureButton()
    end)

    -- Divider
    local div2 = AddDivider(f, -10, normalCheck)

    -- Centered close button
    local closeBtn = CreateAirlineButton(f, 120, 28, "CLOSE")
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ==========================================
    -- KEY INPUT LOGIC
    -- ==========================================
    local pressedBaseKey = nil
    local collectedModifiers = ""

    local function FinalizeInput()
        f:SetScript("OnUpdate", nil)
        f:EnableKeyboard(false)
        if f.mouseCatcher then f.mouseCatcher:Hide() end
        bindBtn.label:SetText("BIND NEW KEY")
        isListening = false
        if not pressedBaseKey then return end

        local fullKey = collectedModifiers .. pressedBaseKey
        local currentAction = GetBindingAction(fullKey)

        if currentAction and currentAction ~= "" and currentAction ~= "CLICK BearplaneModeButton:LeftButton" then
            ShowOverwritePrompt(fullKey, currentAction)
        else
            ApplyBinding(fullKey)
        end
    end

    local function QueueInput(key)
        if not isListening then return end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end

        pressedBaseKey = key
        collectedModifiers = ""
        if IsShiftKeyDown() then collectedModifiers = "SHIFT-" end
        if IsControlKeyDown() then collectedModifiers = "CTRL-" end
        if IsAltKeyDown() then collectedModifiers = "ALT-" end

        local duration = 0
        f:SetScript("OnUpdate", function(_, elapsed)
            duration = duration + elapsed
            if duration >= 0.15 then FinalizeInput() end
        end)
    end

    bindBtn:SetScript("OnClick", function(self)
        if isListening then return end
        bindBtn.label:SetText("|cff00ffffLISTENING...|r")
        pressedBaseKey = nil
        collectedModifiers = ""
        isListening = true
        f:EnableKeyboard(true)

        if not f.mouseCatcher then
            f.mouseCatcher = CreateFrame("Frame", nil, f)
            f.mouseCatcher:SetAllPoints(UIParent)
            f.mouseCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
            f.mouseCatcher:EnableMouse(true)
            f.mouseCatcher:EnableMouseWheel(true)

            f.mouseCatcher:SetScript("OnMouseDown", function(_, button)
                local k = button:upper()
                if k == "LEFTBUTTON" then k = "BUTTON1"
                elseif k == "RIGHTBUTTON" then k = "BUTTON2"
                elseif k == "MIDDLEBUTTON" then k = "BUTTON3" end
                QueueInput(k)
            end)

            f.mouseCatcher:SetScript("OnMouseWheel", function(_, delta)
                QueueInput(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
            end)
        end
        f.mouseCatcher:Show()
    end)

    f:SetScript("OnKeyDown", function(_, key) QueueInput(key) end)

    f:SetScript("OnHide", function()
        if isListening then
            f:SetScript("OnUpdate", nil)
            f:EnableKeyboard(false)
            if f.mouseCatcher then f.mouseCatcher:Hide() end
            bindBtn.label:SetText("BIND NEW KEY")
            isListening = false
            pressedBaseKey = nil
        end
    end)

    f:Hide()
    configWindow = f
    return configWindow
end

-- ==========================================
-- EVENTS
-- ==========================================
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        UpdateSecureButton()

    elseif event == "PLAYER_LOGIN" then
        ClearAllBearplaneBindings()
        RestoreBinding()
        UpdateSecureButton()
        if BearplaneMode_FirstRun then
            BearplaneMode_FirstRun = false
            C_Timer.After(2, function()
                CreateConfigWindow():Show()
                print("|cff00ff00[Bearplane Mode]|r Welcome! Please set a keybind to get started.")
            end)
        end

    elseif event == "PLAYER_ENTERING_WORLD" or
           event == "ZONE_CHANGED" or
           event == "ZONE_CHANGED_NEW_AREA" or
           event == "PLAYER_REGEN_ENABLED" then
        UpdateSecureButton()
    end
end)

-- Slash Command
SLASH_BEARPLANEMODE1 = "/bearplane"
SLASH_BEARPLANEMODE2 = "/bpm"
SlashCmdList["BEARPLANEMODE"] = function()
    local win = CreateConfigWindow()
    if win:IsShown() then win:Hide() else win:Show() end
end