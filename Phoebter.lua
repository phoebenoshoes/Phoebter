-- Phoebter 1.1.1 by Kulusi-ArgentDawn EU ( the phoebster )
-- All rights reserved
local version = C_AddOns.GetAddOnMetadata("Phoebter", "Version") -- get version from .toc 

CurrentBuff = ""
AutoPrism = false
local refreshTongues, refreshInky, refreshPrism = true, true, true -- for if reminder has been declined to prevent it from appearing again. 
---------------------------------------------------------------------not to be confused with CheckX which sets if buff should be checked for at all
TONGUES_ID = 2336
INKY_ID = 185394
PRISM_SPELL_ID = 374957 -- prism has a different id on buff vs when you cast the spell lol
PRISM_BUFF_ID = 374959

-- special button to go over pop up one - cant run macros from there, can here
RefreshButton = CreateFrame("Button", nil, UIParent, "StaticPopupButtonTemplate, InsecureActionButtonTemplate")
RefreshButton:SetAttribute("typerelease", "macro")
RefreshButton:SetAttribute("pressAndHoldAction", "1")
RefreshButton:SetText("Yes")
RefreshButton:SetAttribute("macrotext", "/cast " .. CurrentBuff)
RefreshButton:HookScript( "OnClick", function()
    RefreshClicked()
end)
function RefreshClicked() end

-- creates box to pop up when buffs close to expiring
StaticPopupDialogs["POP_UP_BOX"] = {
	text = CurrentBuff .. " expires soon. Refresh?",
	button1 = "Yes",
	button2 = "No",
    OnShow = function(self)
        -- put special button on top of regular
        self:SetText(CurrentBuff .. " expires soon. Refresh?")
        RefreshButton:SetParent(self)
        RefreshButton:SetAllPoints(self:GetButton1())
        RefreshButton:SetFrameLevel(self:GetButton1():GetFrameLevel() + 1)

        if AutoPrism and CurrentBuff == "Projection Prism" then
            -- if autoprism on
            RefreshButton:SetAttribute("macrotext", "/targetraid\n/cast " .. CurrentBuff)
        elseif CurrentBuff ~= "Projection Prism" then
            -- if not handling prism
            RefreshButton:SetAttribute("macrotext", "/cast " .. CurrentBuff)
        else
            -- if handling prism with autoprism off
            self:Hide()
            RefreshButton:Hide()
            StaticPopup_Show("NO_AUTO_PRISM_POP_UP")
        end
        RefreshClicked = function()
            self:Hide()
        end
        RefreshButton:Show()
    end,
    OnHide = function(self)
        RefreshButton:Hide()
        self:GetButton1():Show()
    end,
    OnCancel = function(self)
        -- prevent popup from reappearing for the buff it was dismissed on
        if CurrentBuff == "Elixir of Tongues" then
            refreshTongues = false
        elseif CurrentBuff == "Inky Black Potion" then
            refreshInky = false
        elseif CurrentBuff == "Projection Prism" then
            refreshPrism = false
        end
    end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- creates box to pop up when prism close to expiring but autoprism is off
StaticPopupDialogs["NO_AUTO_PRISM_POP_UP"] = {
	text = CurrentBuff .. " expires soon.",
	button1 = "Ok",
    OnShow = function(self)
        self:SetText(CurrentBuff .. " expires soon.")
        RefreshButton:Hide()
    end,
    OnAccept = function()
        -- prevents popup from reappearing
        refreshPrism = false
    end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- creates popup box to ask if you want autoprism
StaticPopupDialogs["PRISM_POP_UP_BOX"] = {
	text = "Prismatic Projection applied. Enable automatic refreshing? WARNING: only use this when in a group all using the same appearance.",
	button1 = "Yes",
	button2 = "No",
    OnAccept = function()
        AutoPrism = true
        ToggleMessage(AutoPrism, "Automatic prism refreshing", "autoprism")
    end,
    OnCancel = function()
        AutoPrism = false
        ToggleMessage(AutoPrism, "Automatic prism refreshing", "autoprism")
    end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local auraFrame = CreateFrame("Frame", "AuraFrame", UIParent)
local function eventHandler(self, event, ...)
    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_YELL" then
        -- checks if relevant buffs are applied when message sent in spatial channels
        local tonguesAura, inkyAura, prismAura
        if CheckTongues and refreshTongues then
            tonguesAura = C_UnitAuras.GetPlayerAuraBySpellID(TONGUES_ID)
        end
        if CheckInky and refreshInky then
            inkyAura = C_UnitAuras.GetPlayerAuraBySpellID(INKY_ID)
        end
        if CheckPrism and refreshPrism then
            prismAura = C_UnitAuras.GetPlayerAuraBySpellID(PRISM_BUFF_ID)
        end

        if tonguesAura then
            CurrentBuff = "Elixir of Tongues"
            CheckTime(tonguesAura)
        end
        if inkyAura then
            CurrentBuff = "Inky Black Potion"
            CheckTime(inkyAura)
        end
        if prismAura then
            CurrentBuff = "Projection Prism"
            CheckTime(prismAura)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- checks for reapplying buffs to re-enable popup if it had previously been cancelled
        local target, _, id = ...
        if id and target == "player" then
            if id == TONGUES_ID then
                refreshTongues = true
            elseif id == INKY_ID then
                refreshInky = true
            elseif id == PRISM_SPELL_ID then
                refreshPrism = true
            end
        end
    end
end
auraFrame:SetScript("OnEvent", eventHandler)
auraFrame:RegisterEvent("CHAT_MSG_SAY")
auraFrame:RegisterEvent("CHAT_MSG_EMOTE")
auraFrame:RegisterEvent("CHAT_MSG_YELL")
auraFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

-- if remaining time of buff less than 3 minutes, show pop up
function CheckTime(aura)
    local duration = aura.expirationTime - GetTime()
    if duration < 3 * 60 then
        StaticPopup_Show("POP_UP_BOX")
    end
end

local prismFrame = CreateFrame("Frame", "PrismFrame", UIParent)
local function prismHandler(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- checks for prism on login to ask if you want autoprism
        local prismAura = C_UnitAuras.GetPlayerAuraBySpellID(PRISM_BUFF_ID)
        if prismAura then
            StaticPopup_Show("PRISM_POP_UP_BOX")
        end
    elseif event == "UNIT_AURA" then
        -- checks for prism being applied to ask if you want autoprism
        local target, info = ...
        if target == "player" and info.addedAuras then
            local id = info.addedAuras[1].name
            if id == "Prismatic Projection" then
                StaticPopup_Show("PRISM_POP_UP_BOX")
            end
        end
    end
end
prismFrame:SetScript("OnEvent", prismHandler)
prismFrame:RegisterEvent("UNIT_AURA")
prismFrame:RegisterEvent("PLAYER_LOGIN")

-- slash commands
SLASH_PHOEBTER1, SLASH_PHOEBTER2 = "/pb", "/phoebter"
function SlashCmdList.PHOEBTER(command)
    if command == "" or command == "help" then
        -- help message
        print("Phoebter|cffff80ff v" .. version)
        print("Type |cffab70e3 /pb |cffffffff or |cffab70e3 /phoebter |cffffffff followed by argument.") -- |cff indicates colour change, following 6 digits are hexcode of colour
        print("Valid commands are:")
        print("- |cffab70e3 /pb tongues|cffffffff - toggle checking and automatic refreshing for Elixir of Tongues")
        print("- |cffab70e3 /pb inky|cffffffff - toggle checking and automatic refreshing for Inky Black Potion")
        print("- |cffab70e3 /pb prism|cffffffff - toggle checking for Projection Prism")
        print("- |cffab70e3 /pb autoprism|cffffffff - toggle automatic refreshing for Projection Prism")
        print("- |cffab70e3 /pb show|cffffffff - show current settings")
    elseif command == "tongues" then
        -- toggle tongues
        CheckTongues = not CheckTongues
        ToggleMessage(CheckTongues, "Elixir of Tongues checking and automatic refreshing", command)
    elseif command == "inky" then
        -- toggle inky
        CheckInky = not CheckInky
        ToggleMessage(CheckInky, "Inky Black Potion checking and automatic refreshing", command)
    elseif command == "prism" then
        -- toggle prism checking
        CheckPrism = not CheckPrism
        ToggleMessage(CheckPrism, "Projection Prism checking", command)
    elseif command == "autoprism" then
        -- toggle autoprism
        AutoPrism = not AutoPrism
        ToggleMessage(AutoPrism, "Automatic prism refreshing", command)
    elseif command == "show" then
        -- show current settings
        print("Elixir of Tongues: " .. BoolToOnOff(CheckTongues))
        print("Inky Black Potion: " .. BoolToOnOff(CheckInky))
        print("Projection Prism checking: " .. BoolToOnOff(CheckPrism))
        print("Projection Prism automatic refreshing: " .. BoolToOnOff(AutoPrism))
    end
end

function ToggleMessage(toggled, toggledStr, command)
    local onOff = BoolToOnOff(toggled)
    print(toggledStr .. " turned " .. onOff .. ". Type |cffab70e3/pb " .. command .. "|cffffffff to toggle.")
end

-- converts bool to "on" or "off" with colour shenanigans
function BoolToOnOff(bool)
    if bool then
        return "|cff00ff00on|cffffffff"
    else
        return "|cffff0000off|cffffffff"
    end
end

-- send message once addon has loaded and initialise variables
local onLoadFrame = CreateFrame("Frame", "OnLoadFrame", UIParent)
local function onLoad(self, event, name)
    if event == "ADDON_LOADED" then
        if name == "Phoebter" then
            if CheckTongues == nil then
                CheckTongues = true
            end
            if CheckInky == nil then
                CheckInky = true
            end
            if CheckPrism == nil then
                CheckPrism = true
            end
            print("you are now using a certified phoebster addon :D type |cffab70e3 /pb|cffffffff for help (|cffff80ff v" .. version .. "|cffffffff)")
        end
    end
end
onLoadFrame:SetScript("OnEvent", onLoad)
onLoadFrame:RegisterEvent("ADDON_LOADED")
