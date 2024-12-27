local addonName, addon = ...
local isInitialized = false

-- Constants
local SOAR_SPELL_IDS = {
    369536,  -- Original Dracthyr Soar
    383359,  -- Dracthyr Empowered Soar
    375841,  -- Additional variant
    441313,  -- Additional variant
    430747   -- Additional variant
}

-- Utility Functions
local function Debug(msg)
    if addon.debug then
        print("|cFF00FF00[MountBinder Debug]|r " .. msg)
    end
end

local function GetValidSoarID()
    for _, spellID in ipairs(SOAR_SPELL_IDS) do
        local spellName = GetSpellInfo(spellID)
        if spellName and IsSpellKnown(spellID) then
            Debug("Found valid Soar spell ID: " .. spellID)
            return spellID
        end
    end
    Debug("No valid Soar spell found")
    return nil
end

-- Mount Slot Functions
function addon:CreateMountSlots()
    local basicSlotNames = {"No Mod", "Shift", "Ctrl", "Alt"}
    local advancedSlotNames = {"Shift+Ctrl", "Shift+Alt", "Ctrl+Alt", "Shift+Ctrl+Alt"}
    self.mountSlots = {}

    local yOffset = -30
    for i, name in ipairs(basicSlotNames) do
        local slot = CreateFrame("Button", "MountBinderSlot"..i, self.frame, "MountBinderSlotTemplate")
        slot:SetPoint("TOP", self.frame, "TOP", 0, yOffset)
        slot.text:SetText(name)
        slot.mountID = nil
        slot.isAdvanced = false
        
        -- Set up drag functionality
        slot:RegisterForDrag("LeftButton")
        slot:SetScript("OnDragStart", function(self)
            if self.mountID then
                SetCursor("Interface\\ICONS\\Spell_Nature_Swiftness")
            end
        end)

        slot:SetScript("OnReceiveDrag", function(self)
            local infoType, id = GetCursorInfo()
            if infoType == "mount" then
                self.mountID = id
                local _, _, icon = C_MountJournal.GetMountInfoByID(id)
                self.icon:SetTexture(icon)
                addon:SaveMountSelections()
                Debug("Mount " .. id .. " saved to " .. name .. " slot")
            elseif infoType == "spell" then
                for _, soarID in ipairs(SOAR_SPELL_IDS) do
                    if id == soarID then
                        self.mountID = -id
                        self.icon:SetTexture("Interface\\Icons\\ability_dragonriding_soar")
                        addon:SaveMountSelections()
                        Debug("Soar ability " .. id .. " saved to " .. name .. " slot")
                        break
                    end
                end
            end
            ClearCursor()
        end)

        -- Handle right-click to clear
        slot:RegisterForClicks("AnyUp")
        slot:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                self.mountID = nil
                self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                addon:SaveMountSelections()
                Debug("Cleared " .. name .. " slot")
            end
        end)

        self.mountSlots[i] = slot
        yOffset = yOffset - 35
    end

    -- Create advanced slots
    for i, name in ipairs(advancedSlotNames) do
        local index = i + #basicSlotNames
        local slot = CreateFrame("Button", "MountBinderSlot"..index, self.frame, "MountBinderSlotTemplate")
        slot.text:SetText(name)
        slot.mountID = nil
        slot.isAdvanced = true
        
        -- Copy the same OnDragStart/OnReceiveDrag/OnClick handlers
        slot:RegisterForDrag("LeftButton")
        slot:SetScript("OnDragStart", self.mountSlots[1]:GetScript("OnDragStart"))
        slot:SetScript("OnReceiveDrag", self.mountSlots[1]:GetScript("OnReceiveDrag"))
        slot:RegisterForClicks("AnyUp")
        slot:SetScript("OnClick", self.mountSlots[1]:GetScript("OnClick"))

        self.mountSlots[index] = slot
    end
end

-- Tooltip Functions
function addon:ShowMountTooltip(slot)
    if not slot.mountID then return end

    GameTooltip:SetOwner(slot, "ANCHOR_RIGHT")
    if slot.mountID < 0 then
        -- Soar ability tooltip
        local spellID = -slot.mountID
        GameTooltip:SetSpellByID(spellID)
    else
        -- Mount tooltip
        local name, spellID, icon, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(slot.mountID)
        if name then
            GameTooltip:SetText(name)
            local _, description = C_MountJournal.GetMountInfoExtraByID(slot.mountID)
            if description then
                GameTooltip:AddLine(description, 1, 1, 1, true)
            end
            if not isCollected then
                GameTooltip:AddLine("Mount not collected", 1, 0, 0)
            end
        end
    end
    GameTooltip:Show()
end

-- UI Update Functions
function addon:UpdateMountSlots()
    local yOffset = -30
    local basicSlots = 4

    -- Update basic slots
    for i = 1, basicSlots do
        local slot = self.mountSlots[i]
        slot:Show()
        slot:SetPoint("TOP", self.frame, "TOP", 0, yOffset)
        yOffset = yOffset - 35
    end

    -- Update advanced slots visibility
    if self.advancedMode then
        yOffset = yOffset - 35
        for i = basicSlots + 1, #self.mountSlots do
            local slot = self.mountSlots[i]
            slot:Show()
            slot:SetPoint("TOP", self.frame, "TOP", 0, yOffset)
            yOffset = yOffset - 35
        end
    else
        for i = basicSlots + 1, #self.mountSlots do
            self.mountSlots[i]:Hide()
        end
    end

    self:UpdateFrameSize()
end

function addon:UpdateFrameSize()
    local baseHeight = 200
    local slotHeight = 35
    local visibleSlots = 4

    if self.advancedMode then
        visibleSlots = visibleSlots + 4
    end

    local newHeight = baseHeight + (slotHeight * visibleSlots)
    self.frame:SetSize(220, newHeight)
end

-- Soar Functions
function addon:SetSoarInNoModSlot()
    local soarID = GetValidSoarID()
    if soarID then
        local firstSlot = self.mountSlots[1]
        firstSlot.mountID = -soarID
        firstSlot.icon:SetTexture("Interface\\Icons\\ability_dragonriding_soar")
        Debug("Set Soar " .. soarID .. " in No Mod slot")
        return true
    end
    return false
end

-- Mount Summoning
function addon:SummonMount()
    local index = 1
    if IsShiftKeyDown() and IsControlKeyDown() and IsAltKeyDown() then
        index = 8
    elseif IsShiftKeyDown() and IsControlKeyDown() then
        index = 5
    elseif IsShiftKeyDown() and IsAltKeyDown() then
        index = 6
    elseif IsControlKeyDown() and IsAltKeyDown() then
        index = 7
    elseif IsShiftKeyDown() then
        index = 2
    elseif IsControlKeyDown() then
        index = 3
    elseif IsAltKeyDown() then
        index = 4
    end

    local slot = self.mountSlots[index]
    if slot and slot.mountID then
        if slot.isAdvanced and not self.advancedMode then
            Debug("Advanced Mode not enabled for slot " .. index)
            return
        end

        if slot.mountID < 0 then
            local spellID = -slot.mountID
            if IsSpellKnown(spellID) then
                CastSpellByID(spellID)
                Debug("Cast Soar spell " .. spellID)
            else
                Debug("Soar spell " .. spellID .. " not known")
            end
        else
            C_MountJournal.SummonByID(slot.mountID)
            Debug("Summoned mount " .. slot.mountID)
        end
    end
end

-- Initialization
function addon:Init()
    self.frame = MountBinderFrame
    self.frame.title:SetText("Mount Binder")
    
    -- Set up checkboxes
    self.advancedModeCheckbox = self.frame.advancedMode
    self.advancedModeCheckbox:SetScript("OnClick", function(cb)
        self.advancedMode = cb:GetChecked()
        self:UpdateMountSlots()
        self:SaveMountSelections()
    end)

    self.soarCheckbox = self.frame.useSoar
    self.soarCheckbox:SetScript("OnClick", function(cb)
        self.useSoar = cb:GetChecked()
        if self.useSoar then
            if not self:SetSoarInNoModSlot() then
                self.useSoar = false
                cb:SetChecked(false)
            end
        else
            local firstSlot = self.mountSlots[1]
            if firstSlot.mountID and firstSlot.mountID < 0 then
                firstSlot.mountID = nil
                firstSlot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        end
        self:SaveMountSelections()
    end)

    -- Set up keybind button
    self.keybindButton = self.frame.keybindButton
    self.keybindButton:SetText("Set Mount Keybind")
    self.keybindButton:SetScript("OnClick", function()
        self:SetKeybind()
    end)

    -- Create mount slots
    self:CreateMountSlots()
    
    -- Create summon button
    self:CreateSummonButton()

    -- Set up frame movement
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)

    Debug("Mount Binder initialized")
end

-- Create the action button for summoning the mount
function addon:CreateSummonButton()
    local summonButton = CreateFrame("Button", "MountBinderSummonButton", UIParent, "SecureActionButtonTemplate")
    summonButton:SetAttribute("type", "macro")
    summonButton:SetAttribute("macrotext", "/click MountBinderSummonButton")
    
    summonButton:SetScript("PreClick", function(self)
        addon:SummonMount()
    end)
    Debug("Created summon button")
end

-- Keybind Functions
function addon:SetKeybind()
    local function OnKeyDown(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(true)
            self:EnableKeyboard(false)
            return
        end
        
        self:SetPropagateKeyboardInput(false)
        SetBindingClick(key, "MountBinderSummonButton")
        SaveBindings(2)  -- Account-wide bindings
        
        self:EnableKeyboard(false)
        
        -- Save the key
        addon.keybind = key
        addon:SaveKeybind()
        
        -- Update display
        local bindText = _G[addon.frame:GetName().."KeybindButton"]:GetText()
        if bindText then
            bindText = string.format("Mount Keybind: %s", key)
        end
        
        Debug("Keybind set to: " .. key)
    end

    local keyListener = CreateFrame("Frame", nil, UIParent)
    keyListener:EnableKeyboard(true)
    keyListener:SetPropagateKeyboardInput(true)
    keyListener:SetScript("OnKeyDown", OnKeyDown)
    
    print("Press any key to set the Mount Binder keybind (or ESC to cancel)")
end

-- Event Handling
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        if not isInitialized then
            addon:Init()
            isInitialized = true
            self:RegisterEvent("PLAYER_ENTERING_WORLD")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        addon:LoadMountSelections()
        addon:LoadKeybind()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnEvent)

-- Slash Command
SLASH_MOUNTBINDER1 = "/mountbinder"
SlashCmdList["MOUNTBINDER"] = function(msg)
    if msg == "debug" then
        addon.debug = not addon.debug
        print("MountBinder debug mode: " .. (addon.debug and "ON" or "OFF"))
    else
        if addon.frame:IsShown() then
            addon.frame:Hide()
        else
            addon.frame:Show()
        end
    end
end
