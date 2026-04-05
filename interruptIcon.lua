--------------------------------------------------
-- Constants & Locals
--------------------------------------------------
local ADDON_NAME = "InterruptIcon"
local ICON_ID = 135856
local COOLDOWN_DURATION = 20
local INTERRUPT_SPELL_ID = 2139
local LCG = LibStub("LibCustomGlow-1.0")

--------------------------------------------------
-- Frame Creation
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
    LCG.ProcGlow_Start(frame)
end

local function HideGlow()
    LCG.ProcGlow_Stop(frame)
end

local function IsFocusCasting()
    if not UnitExists("focus") then return false end

    local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("focus")
    if name then
        ShowGlow()
        frame._ProcGlow:SetAlphaFromBoolean(notInterruptible, 0, 1)
        return true
    end

    local channelName, _, _, _, _, _, _, channelNotInterruptible = UnitChannelInfo("focus")
    if channelName then
        ShowGlow()
        frame._ProcGlow:SetAlphaFromBoolean(channelNotInterruptible, 0, 1)
        return true
    end

    return false
end

local function StartInterruptCooldown()
    ShowGlow()
    frame._ProcGlow:SetAlphaFromBoolean(false, 1, 0)

    local duration = InterruptIconDB.cooldown
    cooldown:SetCooldown(GetTime(), duration)
    icon:SetDesaturated(true)

    C_Timer.After(duration, function()
        icon:SetDesaturated(false)

        IsFocusCasting()
    end)
end

local function UpdateVisibility()
    if UnitExists("focus") then
        frame:Show()

        local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("focus")
        if name and cooldown:GetCooldownDuration() == 0 then
            ShowGlow()
            frame._ProcGlow:SetAlphaFromBoolean(notInterruptible, 0, 1)
        else
            HideGlow()
        end
    else
        frame:Hide()
        ShowGlow()
        frame._ProcGlow:SetAlpha(0)
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
        if unit == "player" and spellId == InterruptIconDB.spellId then
            StartInterruptCooldown()
        end
        return
    end

    -- Focus cast start (cast)
    if (event == "UNIT_SPELLCAST_START") then
        if unit == "focus" and cooldown:GetCooldownDuration() == 0 then
            local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("focus")
            ShowGlow()
            frame._ProcGlow:SetAlphaFromBoolean(notInterruptible, 0, 1)
        end

        return
    end

      -- Focus cast start (channel)
    if (event == "UNIT_SPELLCAST_CHANNEL_START") then
        if unit == "focus" and cooldown:GetCooldownDuration() == 0 then
            local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitChannelInfo("focus")
            ShowGlow()
            frame._ProcGlow:SetAlphaFromBoolean(notInterruptible, 0, 1)
        end

        return
    end

    -- Focus cast end (cast or channel)
    if (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP") then
        if unit == "focus" then
            frame._ProcGlow:SetAlpha(0)
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
    InterruptIconDB.size   = InterruptIconDB.size       or 40
    InterruptIconDB.point  = InterruptIconDB.point      or "CENTER"
    InterruptIconDB.x      = InterruptIconDB.x          or 0
    InterruptIconDB.y      = InterruptIconDB.y          or 0
    InterruptIconDB.locked = InterruptIconDB.locked     or false
    InterruptIconDB.iconId   = InterruptIconDB.iconId   or ICON_ID
    InterruptIconDB.cooldown = InterruptIconDB.cooldown or COOLDOWN_DURATION
    InterruptIconDB.spellId  = InterruptIconDB.spellId  or INTERRUPT_SPELL_ID

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

SLASH_INTERRUPTICONICON1 = "/iiicon"
SlashCmdList.INTERRUPTICONICON = function(msg)
    local id = tonumber(msg)
    if id then
        InterruptIconDB.iconId = id
        icon:SetTexture(id)
        print("Interrupt Icon texture set to", id)
    else
        print("Usage: /iiicon <fileID>")
    end
end

SLASH_INTERRUPTICONCOOLDOWN1 = "/iicooldown"
SlashCmdList.INTERRUPTICONCOOLDOWN = function(msg)
    local cd = tonumber(msg)
    if cd and cd > 0 then
        InterruptIconDB.cooldown = cd
        print("Interrupt cooldown set to", cd, "seconds")
    else
        print("Usage: /iicooldown <seconds>")
    end
end

SLASH_INTERRUPTICONSPELLID1 = "/iispellid"
SlashCmdList.INTERRUPTICONSPELLID = function(msg)
    local id = tonumber(msg)
    if id then
        InterruptIconDB.spellId = id
        print("Interrupt spell ID set to", id)
    else
        print("Usage: /iispellid <spellID>")
    end
end

SLASH_INTERRUPTICONRESET1 = "/iireset"
SlashCmdList.INTERRUPTICONRESET = function()
    InterruptIconDB.iconId   = DEFAULTS.iconId
    InterruptIconDB.cooldown = DEFAULTS.cooldown
    InterruptIconDB.spellId  = DEFAULTS.spellId

    icon:SetTexture(InterruptIconDB.iconId)
    print("Interrupt Icon settings reset to defaults")
end

SLASH_INTERRUPTICON1 = "/ii"
SlashCmdList.INTERRUPTICON = function()
    print("Interrupt Icon, usage: ")
    print("/iilock: Locks the icon. ")
    print("/iisize: Resizes the icon. ")
    print("/iitest: Triggers a 'fake' cooldown for testing purposes. ")
    print("/iiicon: Changes the icon to the provided iconID. ")
    print("/iicooldown: Changes the hardcoded cooldown to the provided cooldown (in seconds). ")
    print("/iispellid: Changes the spellID of your kick spell. ")
    print("/iireset: Resets icon, cooldown & spellID to defaults (Mage). Requires reload. ")
end