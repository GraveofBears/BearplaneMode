local addonName, addon = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

BearplaneMode_Keybind = BearplaneMode_Keybind or "BUTTON2"
BearplaneMode_LastSwimmingState = BearplaneMode_LastSwimmingState or false
BearplaneMode_LastIndoorState = BearplaneMode_LastIndoorState or false

local configWindow, promptWindow
local pendingKey = nil
local isListening = false

-- ==========================================
-- TBC ZONE DETECTION ENGINE
-- ==========================================

-- Outland zones (flyable in TBC)
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
	["Island Expeditions"] = true,
	["Karazhan"] = true,
}

-- Old Kingdom dungeons (no flight, indoors)
local OLD_KINGDOM_DUNGEONS = {
	["The Underbog"] = true,
	["The Slave Pens"] = true,
	["The Steamvault"] = true,
	["Auchenai Crypts"] = true,
	["Shadow Labyrinth"] = true,
	["Sethekk Halls"] = true,
	["Mana-Tombs"] = true,
	["The Black Morass"] = true,
	["Old Kingdom"] = true, -- if it shows as this
}

-- Any other TBC dungeons for completeness
local TBC_DUNGEONS = {
	["Hellfire Ramparts"] = true,
	["The Blood Furnace"] = true,
	["The Shattered Halls"] = true,
	["The Botanica"] = true,
	["The Mechanar"] = true,
	["The Arcatraz"] = true,
	["Karazhan"] = true,
	-- Old Kingdom group
	["The Underbog"] = true,
	["The Slave Pens"] = true,
	["The Steamvault"] = true,
	["Auchenai Crypts"] = true,
	["Shadow Labyrinth"] = true,
	["Sethekk Halls"] = true,
	["Mana-Tombs"] = true,
	["The Black Morass"] = true,
}

local function GetEnvironmentInfo()
	local zone = GetZoneText()
	local subzone = GetSubZoneText()
	local indoors = IsIndoors()
	local swimming = IsSwimming()
	local inCombat = UnitAffectingCombat("player")
	
	return {
		zone = zone,
		subzone = subzone,
		indoors = indoors,
		swimming = swimming,
		inCombat = inCombat,
	}
end

local function DetectFormStrategy()
	local env = GetEnvironmentInfo()
	
	-- If in combat, don't change forms
	if env.inCombat then
		return "nocombat"
	end
	
	-- If swimming, use aquatic
	if env.swimming then
		return "aquatic"
	end
	
	-- If indoors (IsIndoors check) or in a dungeon, use cat form
	if env.indoors or TBC_DUNGEONS[env.zone] or TBC_DUNGEONS[env.subzone] then
		return "cat"
	end
	
	-- Check if subzone suggests we're indoors (banks, inns, shops, etc)
	local indoorSubzones = {
		["Bank of Orgrimmar"] = true,
		["Orgrimmar Innkeeper"] = true,
		["Thrall's Throne Room"] = true,
		["Hall of Legends"] = true,
		["Orgrimmar Auction House"] = true,
		["Orgrimmar Trade District"] = true,
		-- Add more as needed
	}
	if indoorSubzones[env.subzone] then
		return "cat"
	end
	
	-- If in Outland and outdoors, use swift flight
	if OUTLAND_ZONES[env.zone] then
		return "flight"
	end
	
	-- If outdoors (not indoors), use travel form
	if not env.indoors then
		return "travel"
	end
	
	-- Default fallback: travel form
	return "travel"
end

local function GenerateSmartMacro()
	local strategy = DetectFormStrategy()
	local env = GetEnvironmentInfo()
	
	local macro = [[#showtooltip
/cancelform [nocombat]

]]
	
	if strategy == "aquatic" then
		-- Swimming - use aquatic, don't cast others while swimming
		macro = macro .. "/cast [swimming] !Aquatic Form\n"
		-- If in Outland, try flight form when NOT swimming, otherwise travel form
		if OUTLAND_ZONES[env.zone] then
			macro = macro .. "/cast [noswimming,flyable,outdoors,nocombat] !Swift Flight Form\n"
		end
		macro = macro .. "/cast [noswimming] !Travel Form\n"
		
	elseif strategy == "flight" then
		-- Outland flying - use swift flight, fall back to travel
		macro = macro .. "/cast [flyable,outdoors,nocombat] !Swift Flight Form\n"
		macro = macro .. "/cast !Travel Form\n"
		
	elseif strategy == "cat" then
		-- Dungeon/Indoor - just use cat form
		macro = macro .. "/cast !Cat Form\n"
		
	else
		-- Default fallback - use travel form
		macro = macro .. "/cast !Travel Form\n"
	end
	
	return macro
end

-- ==========================================
-- FIXED SECURE BUTTON + SMARTER MACRO
-- ==========================================
local secureBtn = CreateFrame("Button", "BearplaneModeButton", UIParent, "SecureActionButtonTemplate")
secureBtn:RegisterForClicks("AnyDown")
secureBtn:SetAttribute("type", "macro")

local lastIndoorState = nil
local lastSwimmingState = nil
local updateTimer = 0

local function UpdateSecureButton()
	local macroText = GenerateSmartMacro()
    secureBtn:SetAttribute("macrotext", macroText)
end

-- Check indoors status frequently
frame:SetScript("OnUpdate", function(self, elapsed)
	updateTimer = updateTimer + elapsed
	-- Update every 0.1 seconds to catch indoor/outdoor changes
	if updateTimer >= 0.1 then
		updateTimer = 0
		local currentIndoorState = IsIndoors()
		local currentSwimmingState = IsSwimming()
		
		-- If indoors state changed, update the macro
		if currentIndoorState ~= BearplaneMode_LastIndoorState then
			BearplaneMode_LastIndoorState = currentIndoorState
			UpdateSecureButton()
		end
		
		-- If swimming state changed, update the macro
		if currentSwimmingState ~= BearplaneMode_LastSwimmingState then
			BearplaneMode_LastSwimmingState = currentSwimmingState
			UpdateSecureButton()
		end
	end
end)

local function ApplyBinding(key)
    if not key or key == "" then return end
    ClearOverrideBindings(secureBtn)
    SetBindingClick(key, "BearplaneModeButton")
    SaveBindings(GetCurrentBindingSet())
    BearplaneMode_Keybind = key
    
    if configWindow and configWindow.currentBindText then
        configWindow.currentBindText:SetText("Current Bind: |cff00ff00" .. key .. "|r")
    end
    print("|cff00ff00[Bearplane Mode]|r Bound to: " .. key)
end

local function ClearOldBindings()
    -- Clear any old bearplane bindings from the system
    ClearOverrideBindings(secureBtn)
    SaveBindings(GetCurrentBindingSet())
end

-- UI Code (Prompt + Config)
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
    f.currentBindText:SetText("Current Bind: |cff00ff00" .. BearplaneMode_Keybind .. "|r")
   
    f.infoText = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.infoText:SetPoint("TOP", f.currentBindText, "BOTTOM", 0, -10)
    f.infoText:SetText("Click below, then press your desired hotkey.")
    
    -- Zone info display
    f.statusText = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    f.statusText:SetPoint("TOP", f.infoText, "BOTTOM", 0, -15)
    f.statusText:SetText("|cffaabbccStatus:|r Detecting...")
    f.statusText:SetWidth(350)
    f.statusText:SetJustifyH("CENTER")
   
    local function UpdateStatusDisplay()
        local env = GetEnvironmentInfo()
        local status = ""
        
        if env.inCombat then
            status = "|cffff0000IN COMBAT|r - No form change"
        elseif env.swimming then
            status = "|cff00ffffSWIMMING|r → Aquatic Form"
        elseif env.indoors then
            status = "|cffff6600INDOORS|r → Cat Form"
        elseif TBC_DUNGEONS[env.zone] or TBC_DUNGEONS[env.subzone] then
            status = "|cffff6600DUNGEON|r → Cat Form"
        elseif OUTLAND_ZONES[env.zone] then
            status = "|cff00ff00OUTLAND|r → Swift Flight Form"
        else
            status = "|cff88ccffOTHER|r → Travel Form"
        end
        
        status = status .. " (" .. env.zone .. ")"
        f.statusText:SetText("|cffaabbccStatus:|r " .. status)
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
    
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 20)
    resetBtn:SetText("Unbind Hotkey")
    resetBtn:SetScript("OnClick", function()
        ClearOverrideBindings(secureBtn)
        SaveBindings(GetCurrentBindingSet())
        BearplaneMode_Keybind = ""
        if f.currentBindText then
            f.currentBindText:SetText("Current Bind: |cffff0000None|r")
        end
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
    
    -- Update status display when window shows
    f:SetScript("OnShow", function()
        UpdateStatusDisplay()
        -- Update every 0.5 seconds while window is open
        f.statusUpdateTimer = 0
        f:SetScript("OnUpdate", function(_, elapsed)
            f.statusUpdateTimer = f.statusUpdateTimer + elapsed
            if f.statusUpdateTimer >= 0.5 then
                UpdateStatusDisplay()
                f.statusUpdateTimer = 0
            end
        end)
    end)
    
    f:SetScript("OnHide", function()
        f:SetScript("OnUpdate", nil)
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
        ClearOldBindings()
        UpdateSecureButton()
       
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or 
           event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
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