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
        local preferenceFrame = player.gui.screen[gui_builder.preferenceFrameName]
        if preferenceFrame then
            preferenceFrame.destroy()
        end
    end
end

function gui.toggleMain(player)
    local mainFrame = player.gui.screen[gui_builder.mainFrameName]
    local preferenceFrame = player.gui.screen[gui_builder.preferenceFrameName]

    if not mainFrame then
        gui_builder.buildMainGui(player)
    else
        if preferenceFrame and preferenceFrame.visible then
            preferenceFrame.visible = false
        end

        mainFrame.visible = not mainFrame.visible
    end
end

function gui.togglePreference(player)
    local preferenceFrame = player.gui.screen[gui_builder.preferenceFrameName]

    if not preferenceFrame then
        gui_builder.buildPreferenceGui(player)
    else
        preferenceFrame.visible = not preferenceFrame.visible
        preferenceFrame.bring_to_front()
    end
end

return gui