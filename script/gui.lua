local gui_builder = require("gui_builder")
local mod_gui = require("mod-gui")

local gui = {}

gui.selected_surface = 1

function gui.init()
    for _, player in pairs(game.connected_players) do
        local buttonFlow = mod_gui.get_button_flow(player)

        -- recreate mod-gui button if it already exists
        local flowButton = buttonFlow[gui_builder.flowButtonName]
        if flowButton then
            flowButton.destroy()
        end

        gui_builder.buildModGuiButton(buttonFlow)

        -- destroy mainFrame if it already exists
        local mainFrame = player.gui.screen[gui_builder.mainFrameName]
        if mainFrame then
            mainFrame.destroy()
        end

        -- destroy settingsFrame if it already exists
        local preferencesFrame = player.gui.screen[gui_builder.preferencesFrameName]
        if preferencesFrame then
            preferencesFrame.destroy()
        end
    end
end

---@param player LuaPlayer
---@param _ LuaGuiElement
function gui.toggleMain(player, _)
    local mainFrame = player.gui.screen[gui_builder.mainFrameName] --[[@as LuaGuiElement]]
    local preferencesFrame = player.gui.screen[gui_builder.preferencesFrameName] --[[@as LuaGuiElement]]

    if not mainFrame then
        gui_builder.buildMainGui(player)
    else
        if preferencesFrame and preferencesFrame.visible then
            preferencesFrame.visible = false
        end

        mainFrame.visible = not mainFrame.visible
        mainFrame.bring_to_front()
        mainFrame.force_auto_center()
    end
end

---@param player LuaPlayer
---@param _ LuaGuiElement
function gui.togglePreferences(player, _)
    local preferencesFrame = player.gui.screen[gui_builder.preferencesFrameName] --[[@as LuaGuiElement]]

    if not preferencesFrame then
        gui_builder.buildPreferencesGui(player)
    else
        preferencesFrame.visible = not preferencesFrame.visible
        preferencesFrame.bring_to_front()
        preferencesFrame.force_auto_center()
    end
end

---@param player LuaPlayer
---@param dropdown LuaGuiElement
function gui.selectedNewSurface(player, dropdown)
    gui.selected_surface = dropdown.selected_index
end

return gui