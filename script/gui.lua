local mod_gui = require("mod-gui")

---@class GUI
local gui = {}

gui.builder = require("script/gui_builder")

---@param player LuaPlayer
function gui.init(player)
    global.gui_selected_surface = global.gui_selected_surface or {}
    global.gui_selected_surface[player.index] = 1

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
    --[[local preferencesFrame = player.gui.screen[gui.builder.preferencesFrameName]
    if preferencesFrame then
        preferencesFrame.destroy()
    --end]]
end

---@param player LuaPlayer
---@return LuaGuiElement?
function gui.get_main(player)
    return player.gui.screen[gui.builder.mainFrameName]
end

--@param player LuaPlayer
--@return LuaGuiElement?
--[[function gui.get_preferences(player)
    return player.gui.screen[gui.builder.preferencesFrameName]
end]]

---@param player LuaPlayer
---@return LuaSurface
function gui.get_selected_surface(player)
    return game.surfaces[global.gui_selected_surface[player.index]]
end

---@param player LuaPlayer
---@param dropdown LuaGuiElement
function gui.selectedNewSurface(player, dropdown)
    local name = dropdown.items[dropdown.selected_index] --[[@as string]]
    local surface = game.get_surface(name)

    if surface and surface.valid then
        global.gui_selected_surface[player.index] = surface.index
    end
end

return gui