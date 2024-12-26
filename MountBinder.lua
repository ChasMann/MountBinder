local addonName, addon = ...
local isInitialized = false  -- Flag to prevent multiple initializations

-- Function to initialize the addon
function addon:Init()
    print("Mount Binder Addon Initializing...")
    
    -- Create the main frame
    self.frame = CreateFrame("Frame", "MountBinderFrame", UIParent, "BasicFrameTemplateWithInset")

    if self.frame then
        print("MountBinderFrame Created Successfully.")
    else
        print("Error: MountBinderFrame failed to create.")
        return
    end
    
    -- Frame attributes
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)  -- Center the frame for easy access
    self.frame:Hide()  -- Frame hidden by default

    -- Make the frame movable
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)

    -- Add title
    self.frame.title = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.frame.title:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 5, -5)
    self.frame.title:SetText("Mount Binder")

    -- Create mount slots
    self:CreateMountSlots()
    -- Create Advanced Mode checkbox
    self:CreateAdvancedModeCheckbox()
    -- Create keybind button
    self:CreateKeybindButton()
    -- Add keybind display (new UI element to show the assigned key)
    self:CreateKeybindDisplay()

    -- Initial frame size update
    self:UpdateFrameSize()

    print("Mount Binder Frame Initialized and ready.")
end

-- Create Advanced Mode checkbox
function addon:CreateAdvancedModeCheckbox()
    local checkbox = CreateFrame("CheckButton", "MountBinderAdvancedMode", self.frame, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    
    local label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetText("Advanced Mode")

    checkbox:SetScript("OnClick", function(self)
        addon.advancedMode = self:GetChecked()
        addon:UpdateMountSlots()
    end)

    self.advancedModeCheckbox = checkbox
end

-- Create mount selection slots with proper size and positioning
function addon:CreateMountSlots()
    local basicSlotNames = {"No Mod", "Shift", "Ctrl", "Alt"}
    local advancedSlotNames = {"Shift+Ctrl", "Shift+Alt", "Ctrl+Alt", "Shift+Ctrl+Alt"}
    self.mountSlots = {}

    for i, name in ipairs(basicSlotNames) do
        self:CreateMountSlot(i, name, false)
    end

    for i, name in ipairs(advancedSlotNames) do
        self:CreateMountSlot(i + #basicSlotNames, name, true)
    end
end

function addon:CreateMountSlot(index, name, isAdvanced)
    local slot = CreateFrame("Button", "MountSlot"..index, self.frame, "SecureActionButtonTemplate")
    slot:SetSize(180, 30)  -- Reduced height
    slot:SetText(name)
    slot:SetNormalFontObject("GameFontNormal")

    local icon = slot:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)  -- Reduced icon size
    icon:SetPoint("LEFT", slot, "LEFT", 5, 0)

    -- Default icon (empty slot)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    slot.icon = icon
    slot.mountID = nil
    slot.isAdvanced = isAdvanced

    -- Enable dragging functionality
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnDragStart", function(self)
        if self.mountID then
            SetCursor("Interface\\ICONS\\Spell_Nature_Swiftness")
        end
    end)

    -- Receive dragged mount and set the icon accordingly
    slot:SetScript("OnReceiveDrag", function(self)
        local infoType, id = GetCursorInfo()
        if infoType == "mount" then
            self.mountID = id
            local _, _, icon = C_MountJournal.GetMountInfoByID(id)
            self.icon:SetTexture(icon)
            addon:SaveMountSelections()
            print("Mount saved for " .. name .. " modifier.")
        else
            print("Invalid drag: not a mount")
        end
        ClearCursor()
    end)

    -- Handle clearing the mount on right-click or Shift+Click
    slot:RegisterForClicks("AnyUp")
    slot:SetScript("OnClick", function(self, button)
        if (button == "RightButton" or IsShiftKeyDown()) and self.mountID then
            self.mountID = nil
            self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")  -- Reset to default icon
            addon:SaveMountSelections()
            print("Mount cleared for " .. name .. " modifier.")
        end
    end)

    self.mountSlots[index] = slot
end

function addon:UpdateMountSlots()
    local yOffset = -30  -- Start below the title
    local basicSlots = 4

    -- Position basic slots
    for i = 1, basicSlots do
        local slot = self.mountSlots[i]
        slot:Show()
        slot:SetPoint("TOP", self.frame, "TOP", 0, yOffset)
        yOffset = yOffset - 35  -- Reduced spacing between slots
    end

    -- Position Advanced Mode checkbox
    self.advancedModeCheckbox:SetPoint("TOP", self.mountSlots[basicSlots], "BOTTOM", -70, -5)
    self.advancedModeCheckbox:Show()

    -- Position advanced slots
    if self.advancedMode then
        yOffset = yOffset - 35  -- Extra space for the checkbox
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
    local baseHeight = 200  -- Base height including title and some padding
    local slotHeight = 35   -- Height of each slot
    local visibleSlots = 4  -- Start with 4 basic slots

    if self.advancedMode then
        visibleSlots = visibleSlots + 4  -- Add 4 more slots for advanced mode
    end

    local newHeight = baseHeight + (slotHeight * visibleSlots)
    self.frame:SetSize(220, newHeight)

    -- Reposition the keybind button and display
    self.keybindButton:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 10)
    self.keybindDisplay:SetPoint("BOTTOM", self.keybindButton, "TOP", 0, 5)
end

-- Adjust the keybind button to avoid covering the stored keybind
function addon:CreateKeybindButton()
    local button = CreateFrame("Button", "MountBinderKeybindButton", self.frame, "UIPanelButtonTemplate")
    button:SetSize(160, 25)  -- Reduced button height
    button:SetText("Set Mount Keybind")
    button:SetScript("OnClick", function() 
        self:SetKeybind()
    end)
    self.keybindButton = button
end

-- Move the keybind display above the button to avoid overlap
function addon:CreateKeybindDisplay()
    self.keybindDisplay = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.keybindDisplay:SetText("No keybind set")  -- Default message
end

-- Update keybind display
function addon:UpdateKeybindDisplay(key)
    if key then
        self.keybindDisplay:SetText("Current Keybind: " .. key)
    else
        self.keybindDisplay:SetText("No keybind set")
    end
end

-- Save the keybind globally
function addon:SetKeybind()
    local function OnKeyDown(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(true)
            self:EnableKeyboard(false)
            return
        end
        
        self:SetPropagateKeyboardInput(false)
        -- Bind the key to the action of summoning the mount
        SetBindingClick(key, "MountBinderSummonButton")
        
        -- Save the keybinding globally
        SaveBindings(2)  -- 2 for Account-wide bindings
        
        self:EnableKeyboard(false)
        print("Mount Binder keybind set to: " .. key)

        -- Save the key in your addon's saved variables
        if not MountBinderGlobalDB then MountBinderGlobalDB = {} end
        MountBinderGlobalDB.keybind = key
        -- Update the UI to show the current keybind
        addon:UpdateKeybindDisplay(key)
    end

    local keyListener = CreateFrame("Frame", nil, UIParent)
    keyListener:EnableKeyboard(true)
    keyListener:SetPropagateKeyboardInput(true)
    keyListener:SetScript("OnKeyDown", OnKeyDown)

    print("Press any key to set the Mount Binder keybind (or ESC to cancel)")
end


-- Create the action button for summoning the mount
function addon:CreateSummonButton()
    local summonButton = CreateFrame("Button", "MountBinderSummonButton", UIParent, "SecureActionButtonTemplate")
    summonButton:SetAttribute("type", "macro")
    summonButton:SetAttribute("macrotext", "/click MountBinderSummonButton")
    
    summonButton:SetScript("PreClick", function(self)
        addon:SummonMount()
    end)
end

-- Summon the mount based on the modifier key
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
        if (index > 4 and not self.advancedMode) then
            print("Advanced Mode is not enabled. Unable to summon this mount.")
            return
        end
        C_MountJournal.SummonByID(slot.mountID)
        print("Summoning mount ID: " .. slot.mountID)
    else
        print("No mount selected for this modifier")
    end
end

-- Main addon file (MountBinder.lua)
function addon:SaveMountSelections()
    MountBinder_SaveMountSelections(self)
end

function addon:LoadMountSelections()
    MountBinder_LoadMountSelections(self)
    self:UpdateMountIcons()  -- Add this line to update icons after loading
    self:UpdateMountSlots()  -- Update slot visibility and frame size
end

-- New function to update mount icons
function addon:UpdateMountIcons()
    for i, slot in ipairs(self.mountSlots) do
        if slot.mountID then
            local _, _, icon = C_MountJournal.GetMountInfoByID(slot.mountID)
            if icon then
                slot.icon:SetTexture(icon)
            else
                slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
        else
            slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
end

-- Save the keybind globally
function addon:SaveKeybind()
    MountBinder_SaveKeybind(self)
end

-- Load the saved keybind and display it
function addon:LoadKeybind()
    MountBinder_LoadKeybind(self)
end

-- Initialize the addon when ADDON_LOADED event fires
local function OnAddonLoaded(self, event, loadedAddonName)
    if loadedAddonName == addonName and not isInitialized then
        print("Mount Binder Addon Loaded.")
        addon:Init()
        addon:CreateSummonButton()  -- Create the summon button when the addon loads
        isInitialized = true
        
        -- Register for PLAYER_ENTERING_WORLD event
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Load mount selections and update icons when player enters world
        addon:LoadMountSelections()
        addon:LoadKeybind()
        print("Mount Binder: Mounts and keybind loaded.")
    end
end

-- Register the events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", OnAddonLoaded)

-- Add slash command to manually show or hide the mount selector
SLASH_MOUNTBINDER1 = "/mountbinder"
SlashCmdList["MOUNTBINDER"] = function(msg)
    if addon.frame:IsShown() then
        addon.frame:Hide()
        print("Mount Binder Hidden.")
    else
        addon.frame:Show()
        print("Mount Binder Shown.")
    end
end