local gui_event_type = {
    [defines.events.on_gui_click] = "on_gui_click"
}

local gui = {}
local gui_handler = {}
local handlers = {}

function handlers.toggle_main(player)
    gui.toggleMain(player)
end

function handlers.toggle_preference(player)
    gui.togglePreference(player)
end

function gui_handler.init(guiInstance)
    gui = guiInstance
end

function gui_handler.handle(event)
    if not event.element then return end

    local tags = event.element.tags
    if tags.mod ~= "constructron" then return end

    -- GUI events always have an associated player
    local player = game.get_player(event.player_index)

    local event_name = gui_event_type[event.name]
    local action_name = tags[event_name]

    if not action_name then return end

    local event_handler = handlers[action_name]

    if not event_handler then return end

    event_handler(player)
end

return gui_handler