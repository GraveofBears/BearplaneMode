local addonName, addon = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

BearplaneMode_Keybind = BearplaneMode_Keybind or ""
if BearplaneMode_FirstRun == nil then
    BearplaneMode_FirstRun = true
end

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
        macro = macro .. "/cast [combat] Travel Form\n"
        macro = macro .. "/cancelform [nocombat]\n"
        macro = macro .. "/cast [nocombat,flyable,outdoors] Swift Flight Form\n"

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

-- The Fix: Assign the dynamic macro layout to fire regardless of what 
-- click type or modifier code is passed to the button frame down the chain.
secureBtn:SetAttribute("macrotext*", "") 

local function UpdateSecureButton()
    if InCombatLockdown() then return end
    
    local macroText = GenerateSmartMacro()
    secureBtn:SetAttribute("macrotext", macroText)
    secureBtn:SetAttribute("macrotext*", macroText) -- Applies layout to all wildcard macro clicks
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
-- UI
-- ==========================================
local function CreatePromptWindow()
    if promptWindow then return promptWindow end
    local pf = CreateFrame("Frame", "BearplanePromptFrame", UIParent, "BackdropTemplate")
    pf:SetSize(320, 140)
    pf:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    pf:SetFrameStrata("DIALOG")
    pf:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    pf.text = pf:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pf.text:SetPoint("TOP", pf, "TOP", 0, -30)
    pf.text:SetWidth(260)
    pf.text:SetJustifyH("CENTER")

    local yesBtn = CreateFrame("Button", nil, pf, "UIPanelButtonTemplate")
    yesBtn:SetSize(90, 24)
    yesBtn:SetPoint("BOTTOMLEFT", pf, "BOTTOMLEFT", 40, 25)
    yesBtn:SetText("Yes")
    yesBtn:SetScript("OnClick", function()
        if pendingKey then ApplyBinding(pendingKey); pendingKey = nil end
        pf:Hide()
    end)

    local noBtn = CreateFrame("Button", nil, pf, "UIPanelButtonTemplate")
    noBtn:SetSize(90, 24)
    noBtn:SetPoint("BOTTOMRIGHT", pf, "BOTTOMRIGHT", -40, 25)
    noBtn:SetText("No")
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
    pf.text:SetText(string.format("The key |cff00ffff%s|r is already bound to:\n|cffffd100%s|r\n\nOverwrite?", key, currentAction))
    pf:Show()
end

local function CreateConfigWindow()
    if configWindow then return configWindow end
    local f = CreateFrame("Frame", "BearplaneConfigFrame", UIParent, "BackdropTemplate")
    f:SetSize(400, 260)
    f:SetPoint("CENTER", UIParent, "CENTER")
    f:SetFrameStrata("HIGH")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f, "TOP", 0, -18)
    f.title:SetText("Bearplane Mode - TBC Edition")

    f.currentBindText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.currentBindText:SetPoint("TOP", f.title, "BOTTOM", 0, -15)
    f.currentBindText:SetText("Current Bind: |cff00ff00" .. (BearplaneMode_Keybind ~= "" and BearplaneMode_Keybind or "|cffff0000None") .. "|r")

    f.infoText = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.infoText:SetPoint("TOP", f.currentBindText, "BOTTOM", 0, -10)
    f.infoText:SetText("Click below, then press your desired hotkey.")

    f.statusText = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.statusText:SetPoint("TOP", f.infoText, "BOTTOM", 0, -15)
    f.statusText:SetText("|cffaabbccStatus:|r Detecting...")
    f.statusText:SetWidth(350)
    f.statusText:SetJustifyH("CENTER")

    local function UpdateStatusDisplay()
        local strategy, zone = DetectFormStrategy()
        local status
        if strategy == "aquatic" then
            status = "|cff00ffffSWIMMING|r -> Aquatic Form"
        elseif strategy == "cat" then
            local indoors = IsIndoors()
            status = (indoors and "|cffff6600INDOORS|r" or "|cffff6600DUNGEON|r") .. " -> Cat Form"
        elseif strategy == "flight" then
            status = "|cff00ff00OUTLAND|r -> Swift Flight Form"
        else
            status = "|cff88ccffOUTDOORS|r -> Travel Form"
        end
        f.statusText:SetText("|cffaabbccStatus:|r " .. status .. " (" .. zone .. ")")
    end

    local bindBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    bindBtn:SetSize(160, 30)
    bindBtn:SetPoint("CENTER", f, "CENTER", 0, -20)
    bindBtn:SetText("Bind New Key")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 22)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 20)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local unbindBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    unbindBtn:SetSize(120, 22)
    unbindBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 48)
    unbindBtn:SetText("Unbind Hotkey")
    unbindBtn:SetScript("OnClick", function()
        UnbindKey()
        f.currentBindText:SetText("Current Bind: |cffff0000None|r")
    end)

    local pressedBaseKey = nil
    local collectedModifiers = ""

    local function FinalizeInput()
        f:SetScript("OnUpdate", nil)
        f:EnableKeyboard(false)
        if f.mouseCatcher then f.mouseCatcher:Hide() end
        bindBtn:SetText("Bind New Key")
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
        self:SetText("|cff00ffffListening...|r")
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

    f:SetScript("OnShow", function()
        UpdateStatusDisplay()
    end)

    local statusTicker
    f:HookScript("OnShow", function()
        if statusTicker then statusTicker:Cancel() end
        statusTicker = C_Timer.NewTicker(0.5, function()
            if f:IsShown() then UpdateStatusDisplay() end
        end)
    end)

    f:SetScript("OnHide", function()
        if isListening then
            f:SetScript("OnUpdate", nil)
            f:EnableKeyboard(false)
            if f.mouseCatcher then f.mouseCatcher:Hide() end
            bindBtn:SetText("Bind New Key")
            isListening = false
            pressedBaseKey = nil
        end
        if statusTicker then
            statusTicker:Cancel()
            statusTicker = nil
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