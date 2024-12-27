-- Initialize saved variables
MountBinderDB = MountBinderDB or {}
MountBinderGlobalDB = MountBinderGlobalDB or {}

-- Save mount selections to the database for the current character
function MountBinder_SaveMountSelections(addon)
    local playerName = UnitName("player")
    local realmName = GetRealmName()  
    local fullName = playerName .. "-" .. realmName  -- Combine player and realm for unique identifier

    if not MountBinderDB[fullName] then MountBinderDB[fullName] = {} end

    MountBinderDB[fullName].advancedMode = addon.advancedMode
    MountBinderDB[fullName].useSoar = addon.useSoar

    MountBinderDB[fullName].mounts = {}
    for i, slot in ipairs(addon.mountSlots) do
        MountBinderDB[fullName].mounts[i] = slot.mountID  -- Save the mount ID for each slot
    end
    print("Mount selections and settings saved for " .. fullName)
end

-- Load mount selections from the database for the current character
function MountBinder_LoadMountSelections(addon)
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    local fullName = playerName .. "-" .. realmName

    if not MountBinderDB[fullName] then
        print("No saved mounts found for " .. fullName)
        return
    end

    addon.advancedMode = MountBinderDB[fullName].advancedMode or false
    addon.useSoar = MountBinderDB[fullName].useSoar or false
    addon.advancedModeCheckbox:SetChecked(addon.advancedMode)
    addon.soarCheckbox:SetChecked(addon.useSoar)
    addon:UpdateMountSlots()

    local slotNames = {
        "No Mod", "Shift", "Ctrl", "Alt",
        "Shift+Ctrl", "Shift+Alt", "Ctrl+Alt", "Shift+Ctrl+Alt"
    }

    for i, mountID in ipairs(MountBinderDB[fullName].mounts or {}) do
        local slot = addon.mountSlots[i]
        if slot and mountID then
            slot.mountID = mountID  -- Assign the saved mount ID to the slot
            local _, name = C_MountJournal.GetMountInfoByID(mountID)
            if name then
                print("Loaded mount: " .. name .. " for " .. slotNames[i] .. " modifier")
            else
                print("Failed to load mount ID: " .. mountID .. " (" .. slotNames[i] .. " modifier)")
                slot.mountID = nil  -- Reset mountID if the mount is no longer available
            end
        elseif slot then
            slot.mountID = nil
            print("No mount set for " .. slotNames[i] .. " modifier")
        end
    end
    print("Mount selections and settings loaded for " .. fullName)
end

-- Save the keybind globally
function MountBinder_SaveKeybind(addon)
    MountBinderGlobalDB.keybind = addon.keybind
    print("Keybind saved globally: " .. (addon.keybind or "None"))
end

-- Load the saved keybind
function MountBinder_LoadKeybind(addon)
    local keybind = MountBinderGlobalDB.keybind
    if keybind then
        addon.keybind = keybind
        SetBindingClick(keybind, "MountBinderSummonButton")
        addon:UpdateKeybindDisplay(keybind)
        print("Loaded keybind: " .. keybind)
    else
        addon:UpdateKeybindDisplay(nil)
        print("No keybind found.")
    end
end
