local mod_gui = require("mod-gui")

---@type GUI
local gui = {}

gui.selected_surface = {}
gui.builder = require("gui_builder")

---@param player LuaPlayer
function gui.init(player)
    gui.selected_surface[player.index] = 1

    local buttonFlow = mod_gui.get_button_flow(player)

    -- recreate mod-gui button if it already exists
    local flowButton = buttonFlow[gui.builder.flowButtonName]
    if flowButton then
        flowButton.destroy()
    end

    gui.builder.buildModGuiButton(buttonFlow)

    -- destroy mainFrame if it already exists
    local mainFrame = player.gui.screen[gui.builder.mainFrameName]
    if mainFrame then
        mainFrame.destroy()
    end

    -- destroy settingsFrame if it already exists
    local preferencesFrame = player.gui.screen[gui.builder.preferencesFrameName]
    if preferencesFrame then
        preferencesFrame.destroy()
    end
end

---@param player LuaPlayer
---@param _ LuaGuiElement
function gui.toggleMain(player, _)
    local mainFrame = player.gui.screen[gui.builder.mainFrameName] --[[@as LuaGuiElement]]
    local preferencesFrame = player.gui.screen[gui.builder.preferencesFrameName] --[[@as LuaGuiElement]]

    if not mainFrame then
        gui.builder.buildMainGui(player)

        player.opened = player.gui.screen[gui.builder.mainFrameName]
    else
        if preferencesFrame then
            preferencesFrame.visible = false
        end

        if not mainFrame.visible then
            mainFrame.visible = true
            mainFrame.bring_to_front()
            mainFrame.force_auto_center()

            player.opened = mainFrame
        else
            mainFrame.visible = false
        end
    end
end

---@param player LuaPlayer
---@param _ LuaGuiElement
function gui.togglePreferences(player, _)
    local preferencesFrame = player.gui.screen[gui.builder.preferencesFrameName] --[[@as LuaGuiElement]]

    if not preferencesFrame then
        gui.builder.buildPreferencesGui(player)
    else
        preferencesFrame.visible = not preferencesFrame.visible
        preferencesFrame.bring_to_front()
        preferencesFrame.force_auto_center()
    end
end

---@param player LuaPlayer
---@param dropdown LuaGuiElement
function gui.selectedNewSurface(player, dropdown)
    local name = dropdown.items[dropdown.selected_index] --[[@as string]]
    local surface = game.get_surface(name)

    if surface and surface.valid then
        gui.selected_surface[player.index] = surface.index
    end
end

return gui