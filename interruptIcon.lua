--------------------------------------------------
-- Constants & Locals
--------------------------------------------------
local ADDON_NAME = ...
local ICON_ID = 135856
local COOLDOWN_DURATION = 20
local INTERRUPT_SPELL_ID = 2139

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
        InterruptIconDB.size = size
        frame:SetSize(size, size)
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