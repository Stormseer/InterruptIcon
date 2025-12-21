--------------------------------------------------
-- Constants & Locals
--------------------------------------------------
local ADDON_NAME = "InterruptIcon"
local ICON_ID = 135856
local COOLDOWN_DURATION = 20
local INTERRUPT_SPELL_ID = 2139
local settingsCategory

--------------------------------------------------
-- Frame Creation (no SavedVariables used here)
--------------------------------------------------
local frame = CreateFrame("Frame", "InterruptIconFrame", UIParent)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)

--------------------------------------------------
-- Icon Texture
--------------------------------------------------
local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture(ICON_ID)

--------------------------------------------------
-- Cooldown Swipe
--------------------------------------------------
local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
cooldown:SetAllPoints()

--------------------------------------------------
-- Helper Functions
--------------------------------------------------
local function ShowGlow()
    ActionButtonSpellAlertManager:ShowAlert(frame)
end

local function HideGlow()
    ActionButtonSpellAlertManager:HideAlert(frame)
end

local function IsFocusCasting()
    if not UnitExists("focus") then return false end

    local name = UnitCastingInfo("focus")
    if name then
        return true
    end

    local channel = UnitChannelInfo("focus")
    if channel then
        return true
    end

    return false
end

local function StartInterruptCooldown()
    HideGlow()

    cooldown:SetCooldown(GetTime(), COOLDOWN_DURATION)
    icon:SetDesaturated(true)

    C_Timer.After(COOLDOWN_DURATION, function()
        icon:SetDesaturated(false)

        if IsFocusCasting() then
            ShowGlow()
        end
    end)
end

local function UpdateVisibility()
    if UnitExists("focus") then
        frame:Show()
    else
        frame:Hide()
        HideGlow() 
    end
end

local function UpdateSize(size)
    InterruptIconDB.size = size
    frame:SetSize(size, size)
end

--------------------------------------------------
-- Drag Handling
--------------------------------------------------
frame:SetScript("OnDragStart", function(self)
    if not InterruptIconDB.locked then
        self:StartMoving()
    end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()

    if not InterruptIconDB.locked then
        local point, _, _, x, y = self:GetPoint()
        InterruptIconDB.point = point
        InterruptIconDB.x = x
        InterruptIconDB.y = y
    end
end)

--------------------------------------------------
-- Events
--------------------------------------------------
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:SetScript("OnEvent", function(_, event, unit, _, spellId)

    -- Check if there is a focus target. 
    if event == "PLAYER_FOCUS_CHANGED" then
        UpdateVisibility()
        return
    end

    -- Interrupt cooldown logic
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and spellId == INTERRUPT_SPELL_ID then
            StartInterruptCooldown()
        end
        return
    end

    -- Focus cast start (cast or channel)
    if (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") then
        if unit == "focus" then
            if cooldown:GetCooldownDuration() == 0 then
                ShowGlow()
            end
        end
        return
    end

    -- Focus cast end (cast or channel)
    if (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP") then
        if unit == "focus" then
            HideGlow()
        end
        return
    end
end)

--------------------------------------------------
-- SavedVariables/Addon Loader
--------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")

init:SetScript("OnEvent", function(_, _, name)
    if name ~= ADDON_NAME then return end

    InterruptIconDB = InterruptIconDB or {}
    InterruptIconDB.size   = InterruptIconDB.size   or 40
    InterruptIconDB.point  = InterruptIconDB.point  or "CENTER"
    InterruptIconDB.x      = InterruptIconDB.x      or 0
    InterruptIconDB.y      = InterruptIconDB.y      or 0
    InterruptIconDB.locked = InterruptIconDB.locked or false

    frame:SetSize(InterruptIconDB.size, InterruptIconDB.size)

    frame:ClearAllPoints()
    frame:SetPoint(
        InterruptIconDB.point,
        UIParent,
        InterruptIconDB.point,
        InterruptIconDB.x,
        InterruptIconDB.y
    )

    frame:EnableMouse(not InterruptIconDB.locked)
    UpdateVisibility()
end)

--------------------------------------------------
-- Slash Commands
--------------------------------------------------
SLASH_INTERRUPTICONSIZE1 = "/iisize"
SlashCmdList.INTERRUPTICONSIZE = function(msg)
    local size = tonumber(msg)
    if size then
        UpdateSize(size)
        print("Interrupt Icon size set to", size)
    end
end

SLASH_INTERRUPTICONTEST1 = "/iitest"
SlashCmdList.INTERRUPTICONTEST = function()
    StartInterruptCooldown()
    print("Interrupt Icon cooldown triggered")
end

SLASH_INTERRUPTICONLOCK1 = "/iilock"
SlashCmdList.INTERRUPTICONLOCK = function()
    InterruptIconDB.locked = not InterruptIconDB.locked

    if InterruptIconDB.locked then
        frame:EnableMouse(false)
        print("Interrupt Icon locked")
    else
        frame:EnableMouse(true)
        print("Interrupt Icon unlocked (drag to move)")
    end
end

SLASH_INTERRUPTICONOPTIONS1 = "/iioptions"
SlashCmdList.INTERRUPTICONOPTIONS = function()
    if Settings and Settings.OpenToCategory then
        if settingsCategory and settingsCategory.GetID then
            Settings.OpenToCategory(settingsCategory:GetID())
        else
            Settings.OpenToCategory(ADDON_NAME)
        end
    else
        print("|cffffff00["..ADDON_NAME.."]|r Unable to open options menu. Try manually?")
    end
end

SLASH_INTERRUPTICON1 = "/ii"
SlashCmdList.INTERRUPTICON = function()
    print("Interrupt Icon, usage: ")
    print("/iioptions: Opens the options menu. ")
    print("/iilock: Locks the icon. ")
    print("/iisize: Resizes the icon. ")
    print("/iitest: Triggers a 'fake' cooldown for testing purposes. ")
end

-----------------------------------------------------------------------
-- 💀💀💀💀
-- It's all Options Panel from down here (enter at your own risk)
-----------------------------------------------------------------------
do
    local panel = CreateFrame("Frame", "InterruptIconOptionsPanel")
    panel.name = "Interrupt Icon"
    panel:Hide()

    InterruptIconOptions = InterruptIconOptions or {}

    panel:SetScript("OnShow", function(self)
        if self.initialized then return end
        self.initialized = true

        ----------------------------------------------------------------
        -- Title & description
        ----------------------------------------------------------------
        local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Interrupt Icon")

        local desc = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        desc:SetJustifyH("LEFT")
        desc:SetText("Made by Aryella on Silvermoon EU")

        local kickCooldownLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        kickCooldownLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
        kickCooldownLabel:SetText("Kick cooldown: ")

        local kickCooldownEditBox = CreateFrame("EditBox", "InterruptIconKickCooldownEditBox", self, "InputBoxTemplate")
        kickCooldownEditBox:SetSize(35, 20)
        kickCooldownEditBox:SetPoint("LEFT", kickCooldownLabel, "RIGHT", 10, 0)
        kickCooldownEditBox:SetAutoFocus(false)
        kickCooldownEditBox:SetText("20")

        local kickSpellIDLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        kickSpellIDLabel:SetPoint("TOPLEFT", kickCooldownLabel, "BOTTOMLEFT", 0, -10)
        kickSpellIDLabel:SetText("Kick Spell ID: ")

        local kickSpellIDEditBox = CreateFrame("EditBox", "InterruptIconKickSpellIDEditBox", self, "InputBoxTemplate")
        kickSpellIDEditBox:SetSize(65, 20)
        kickSpellIDEditBox:SetPoint("LEFT", kickSpellIDLabel, "RIGHT", 10, 0)
        kickSpellIDEditBox:SetAutoFocus(false)
        kickSpellIDEditBox:SetText("2139")

        local kickSpellIconLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        kickSpellIconLabel:SetPoint("TOPLEFT", kickSpellIDLabel, "BOTTOMLEFT", 0, -10)
        kickSpellIconLabel:SetText("Kick Spell Icon ID: ")

        local kickSpellIconEditBox = CreateFrame("EditBox", "InterruptIconKickSpellIconEditBox", self, "InputBoxTemplate")
        kickSpellIconEditBox:SetSize(80, 20)
        kickSpellIconEditBox:SetPoint("LEFT", kickSpellIconLabel, "RIGHT", 10, 0)
        kickSpellIconEditBox:SetAutoFocus(false)
        kickSpellIconEditBox:SetText("135856")

        local kickIconSizeLabel = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        kickIconSizeLabel:SetPoint("TOPLEFT", kickSpellIconLabel, "BOTTOMLEFT", 0, -10)
        kickIconSizeLabel:SetText("Kick Icon Size: ")

        local kickIconSizeEditBox = CreateFrame("EditBox", "InterruptIconKickIconSizeEditBox", self, "InputBoxTemplate")
        kickIconSizeEditBox:SetSize(35, 20)
        kickIconSizeEditBox:SetPoint("LEFT", kickIconSizeLabel, "RIGHT", 10, 0)
        kickIconSizeEditBox:SetAutoFocus(false)
        kickIconSizeEditBox:SetText("40")

        local hint = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", kickIconSizeLabel, "BOTTOMLEFT", 0, -20)
        hint:SetJustifyH("LEFT")
        hint:SetText("All default values here are for Mages. \n" .. 
                    "If you're not a Mage, you have to edit everything in this menu for the addon to function. \n" .. 
                    "Also... If your class has a variable kick cooldown, then this kinda won't work for you :)")
    end)

    -------------------------------------------------------------------
    -- Register with Settings / Interface Options
    -------------------------------------------------------------------
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(settingsCategory)
    else
        -- Something is wrong and can't make the options menu. AKA fuck handling multiple client versions. 
        if not InterruptIconOptions_NoInterfaceOptionsWarning then
            InterruptIconOptions_NoInterfaceOptionsWarning = true
            print("InterruptIcon: Unable to register options panel: no Settings or InterfaceOptions API found.")
        end
    end
end