--------------------------------------------------
-- Constants & Locals
--------------------------------------------------
local ADDON_NAME = "InterruptIcon"
local ICON_ID = 135856
local COOLDOWN_DURATION = 20
local INTERRUPT_SPELL_ID = 2139
local LCG = LibStub("LibCustomGlow-1.0")

--------------------------------------------------
-- Container Frame (for moving both together)
--------------------------------------------------
local container = CreateFrame("Frame", "InterruptIconContainer", UIParent)
container:SetMovable(true)
container:RegisterForDrag("LeftButton")
container:SetClampedToScreen(true)

--------------------------------------------------
-- Normal Frame (shown most of the time, no glow)
--------------------------------------------------
local normalFrame = CreateFrame("Frame", "InterruptIconNormalFrame", container)
normalFrame:SetAllPoints()
normalFrame:EnableMouse(disable)

local normalIcon = normalFrame:CreateTexture(nil, "ARTWORK")
normalIcon:SetAllPoints()
normalIcon:SetTexture(ICON_ID)

local normalCooldown = CreateFrame("Cooldown", nil, normalFrame, "CooldownFrameTemplate")
normalCooldown:SetAllPoints()

--------------------------------------------------
-- Glow Frame (shown only when glowing)
--------------------------------------------------
local glowFrame = CreateFrame("Frame", "InterruptIconGlowFrame", container)
glowFrame:SetAllPoints()
glowFrame:EnableMouse(disable)

local glowIcon = glowFrame:CreateTexture(nil, "ARTWORK")
glowIcon:SetAllPoints()
glowIcon:SetTexture(ICON_ID)

local glowCooldown = CreateFrame("Cooldown", nil, glowFrame, "CooldownFrameTemplate")
glowCooldown:SetAllPoints()

--------------------------------------------------
-- Helper Functions
--------------------------------------------------
local function ShowGlow()
    LCG.ButtonGlow_Start(glowFrame)
    glowFrame:SetAlpha(1)
    normalFrame:SetAlpha(0)
end

local function HideGlow()
    LCG.ButtonGlow_Start(glowFrame)
    glowFrame:SetAlpha(0)
    normalFrame:SetAlpha(1)
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

    -- Set cooldown on both frames to keep them in sync
    local now = GetTime()
    normalCooldown:SetCooldown(now, COOLDOWN_DURATION)
    glowCooldown:SetCooldown(now, COOLDOWN_DURATION)

    normalIcon:SetDesaturated(true)
    glowIcon:SetDesaturated(true)

    C_Timer.After(COOLDOWN_DURATION, function()
        normalIcon:SetDesaturated(false)
        glowIcon:SetDesaturated(false)

        if IsFocusCasting() then
            ShowGlow()
        end
    end)
end

local function UpdateVisibility()
    if UnitExists("focus") then
        container:Show()
    else
        container:Hide()
        HideGlow()
    end
end

local function UpdateSize(size)
    InterruptIconDB.size = size
    container:SetSize(size, size)
end

--------------------------------------------------
-- Drag Handling
--------------------------------------------------
container:SetScript("OnDragStart", function(self)
    if not InterruptIconDB.locked then
        self:StartMoving()
    end
end)

container:SetScript("OnDragStop", function(self)
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
container:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
container:RegisterEvent("UNIT_SPELLCAST_START")
container:RegisterEvent("UNIT_SPELLCAST_STOP")
container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
container:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
container:RegisterEvent("PLAYER_FOCUS_CHANGED")
container:SetScript("OnEvent", function(_, event, unit, _, spellId)

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
    if event == "UNIT_SPELLCAST_START" then
        if unit == "focus" and normalCooldown:GetCooldownDuration() == 0 then
            local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("focus")
            if name then
                -- Show glow frame only if interruptible (notInterruptible is false)
                LCG.ButtonGlow_Start(glowFrame)
                glowFrame:SetAlphaFromBoolean(notInterruptible, 0, 1)
                normalFrame:SetAlphaFromBoolean(notInterruptible, 1, 0)
                LCG.ButtonGlow_Start(glowFrame)
            end
        end
        return
    end
    
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if unit == "focus" and normalCooldown:GetCooldownDuration() == 0 then
            local name, text, texture, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo("focus")
            if name then
                -- Show glow frame only if interruptible (notInterruptible is false)
                LCG.ButtonGlow_Start(glowFrame)
                glowFrame:SetAlphaFromBoolean(notInterruptible, 0, 1)
                normalFrame:SetAlphaFromBoolean(notInterruptible, 1, 0)
                LCG.ButtonGlow_Start(glowFrame)
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

    container:SetSize(InterruptIconDB.size, InterruptIconDB.size)

    container:ClearAllPoints()
    container:SetPoint(
        InterruptIconDB.point,
        UIParent,
        InterruptIconDB.point,
        InterruptIconDB.x,
        InterruptIconDB.y
    )

    container:EnableMouse(not InterruptIconDB.locked)
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
        container:EnableMouse(false)
        print("Interrupt Icon locked")
    else
        container:EnableMouse(true)
        print("Interrupt Icon unlocked (drag to move)")
    end
end

SLASH_INTERRUPTICON1 = "/ii"
SlashCmdList.INTERRUPTICON = function()
    print("Interrupt Icon, usage: ")
    print("/iilock: Locks the icon. ")
    print("/iisize: Resizes the icon. ")
    print("/iitest: Triggers a 'fake' cooldown for testing purposes. ")
end