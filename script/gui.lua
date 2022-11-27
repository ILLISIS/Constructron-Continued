local gui_builder = require("gui_builder")
local mod_gui = require("mod-gui")

local gui = {}

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

function gui.toggleMain(player)
    local mainFrame = player.gui.screen[gui_builder.mainFrameName]
    local preferencesFrame = player.gui.screen[gui_builder.preferencesFrameName]

    if not mainFrame then
        gui_builder.buildMainGui(player)
    else
        if preferencesFrame and preferencesFrame.visible then
            preferencesFrame.visible = false
        end

        mainFrame.visible = not mainFrame.visible
        mainFrame.bring_to_front()
    end
end

function gui.togglePreferences(player)
    local preferencesFrame = player.gui.screen[gui_builder.preferencesFrameName]

    if not preferencesFrame then
        gui_builder.buildPreferencesGui(player)
    else
        preferencesFrame.visible = not preferencesFrame.visible
        preferencesFrame.bring_to_front()
    end
end

return gui