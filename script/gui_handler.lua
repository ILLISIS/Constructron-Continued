local ctron = require("script/constructron")

local gui_event_type = {
    [defines.events.on_gui_click] = "on_gui_click",
    [defines.events.on_gui_selection_state_changed] = "on_gui_selection_state_changed",
    [defines.events.on_gui_selected_tab_changed] = "on_gui_selected_tab_changed"
}

local gui = require("script/gui")
---@class GUIHandler
local gui_handler = {}
---@class GUIHandlerFunctions
local handlers = {}

---@param player LuaPlayer
---@param _ LuaGuiElement | nil
function handlers.toggle_main(player, _)
    local mainFrame = gui.get_main(player)
    local preferencesFrame = gui.get_preferences(player)

    if not mainFrame then
        gui.builder.buildMainGui(player)
        gui_handler.update(player)

        player.opened = gui.get_main(player)
    else
        if preferencesFrame then
            preferencesFrame.visible = false
        end

        if not mainFrame.visible then
            mainFrame.visible = true
            mainFrame.bring_to_front()
            mainFrame.force_auto_center()

            gui_handler.update(player)

            player.opened = mainFrame
        else
            mainFrame.visible = false

            player.opened = nil
        end
    end
end

---@param player LuaPlayer
---@param _ LuaGuiElement | nil
function handlers.toggle_preferences(player, _)
    local preferencesFrame = gui.get_preferences(player)

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
function handlers.selected_new_surface(player, dropdown)
    gui.selectedNewSurface(player, dropdown)

    local mainFrame = gui.get_main(player)

    if not mainFrame then
        return
    end

    local tab_pane = mainFrame["main"]["tab_pane"] --[[@as LuaGuiElement]]

    update_no_entity_text(player, tab_pane)
    handlers.update_tab_content(player, tab_pane)
end

---@param player LuaPlayer
---@param tab_pane LuaGuiElement
function handlers.update_tab_content(player, tab_pane)
    update_tab_badges(player, tab_pane)

    local container = tab_pane.tabs[tab_pane.selected_tab_index]
    local content = container.content
    local tab = container.tab

    local surface = gui.get_selected_surface(player)

    local no_entity = content["frame"]["no_entity"] --[[@as LuaGuiElement]]
    no_entity["flow"]["label"].caption = {"gui.tab-empty-warn", {"gui." .. tab.tags["tab_type"]}, surface.name}
    no_entity.visible = tab.badge_text == "0"

    local list = content["frame"]["scroll"]["table"] --[[@as LuaGuiElement]]
    list.clear()

    if no_entity.visible then
        return
    end

    local constructrons = get_all_from_surface_with_state(surface.index, tab.tags["tab_type"] --[[@as ConstructronColorStatus]])

    for _, constructron in pairs(constructrons) do
        gui.builder.buildItem(list, constructron, tab.tags["tab_type"] == "idle")
    end
end

---@param player LuaPlayer
---@param tab_pane LuaGuiElement
function update_no_entity_text(player, tab_pane)
    local surface = gui.get_selected_surface(player)

    for _, container in pairs(tab_pane.tabs) do
        local no_entity = container.content["frame"]["no_entity"] --[[@as LuaGuiElement]]
        no_entity["flow"]["label"].caption = {"gui.tab-empty-warn", {"gui." .. container.tab.tags["tab_type"]}, surface.name}
    end
end

---@param player LuaPlayer
---@param tab_pane LuaGuiElement
function update_tab_badges(player, tab_pane)
    local containers = tab_pane.tabs

    local surface = gui.get_selected_surface(player)

    for _, container in pairs(containers) do
        local tab = container.tab
        local count = #get_all_from_surface_with_state(surface.index, tab.tags["tab_type"] --[[@as ConstructronColorStatus]])

        if count < 1000 then
            tab.badge_text = count
        else
            tab.badge_text = "999+"
        end
    end
end

---@param index uint
---@param state ConstructronColorStatus
---@return LuaEntity[]
function get_all_from_surface_with_state(index, state)
    local res = {}

    for _, constructron in pairs(global.constructrons) do
        if constructron.valid and constructron.surface.index == index then
            local status = ctron.get_constructron_status(constructron, "color")

            if status == state then
                res[#res+1] = constructron
            end
        end
    end

    return res
end

---@param player LuaPlayer
---@param button LuaGuiElement
function handlers.open_ctron_map(player, button)
    local constructron = global.constructrons[button.tags["unit"] --[[@as uint]]]

    if player.surface ~= constructron.surface then
        return
    end

    handlers.toggle_main(player)
    player.open_map(global.constructrons[button.tags["unit"] --[[@as uint]]].position, 0.25)
end

---@param player LuaPlayer
---@param button LuaGuiElement
function handlers.get_ctron_remote(player, button)
    local constructron = global.constructrons[button.tags["unit"] --[[@as uint]]]

    if player.clear_cursor() then
        player.cursor_stack.set_stack({name = "constructron-remote", count = 1})
        player.cursor_stack.connected_entity = constructron
    end
end

---@param player LuaPlayer
---@param button LuaGuiElement
function handlers.recall_ctron(player, button)
end


function gui_handler.register()
    for ev, _ in pairs(gui_event_type) do
        script.on_event(ev, gui_handler.gui_event)
    end
end

---@param event 
---| EventData.on_gui_click 
---| EventData.on_gui_selection_state_changed
---| EventData.on_gui_selected_tab_changed
function gui_handler.gui_event(event)
    if not event.element then return end

    local tags = event.element.tags
    if tags.mod ~= "constructron" then return end

    -- GUI events always have an associated player
    local player = game.get_player(event.player_index)
    if not player then return end

    local event_name = gui_event_type[event.name]
    local action_name = tags[event_name]

    if not action_name then return end

    local event_handler = handlers[action_name]

    if not event_handler then return end

    event_handler(player, event.element)
end

---@param event EventData.on_surface_created
function gui_handler.surface_created(event)
    local name = game.surfaces[event.surface_index].name

    for _, player in pairs(game.players) do
        local frame = gui.get_main(player)

        if not frame or not frame.valid then
            goto continue
        end

        local surface_selection = frame["title_bar"]["surface_select"] --[[@as LuaGuiElement]]

        surface_selection.add_item(name)
        surface_selection.visible = true

        ::continue::
    end
end

---@param event EventData.on_surface_deleted
function gui_handler.surface_deleted(event)
    local removed_name = game.surfaces[event.surface_index].name

    for _, player in pairs(game.players) do
        local frame = gui.get_main(player)

        if not frame or not frame.valid then
            goto continue
        end

        local surface_selection = frame["title_bar"]["surface_select"] --[[@as LuaGuiElement]]
        local current_items = surface_selection.items

        for i, name in ipairs(current_items) do --[[@cast i uint]]
            if name == removed_name then
                if i == surface_selection.selected_index then
                    -- current selection gets removed -> fallback to nauvis
                    surface_selection.selected_index = 1

                    handlers.selected_new_surface(player, surface_selection)
                end

                surface_selection.remove_item(i)
                break
            end
        end

        if #surface_selection.items == 1 then
            -- hide selection if only 1 surface is left
            surface_selection.visible = false
        end

        ::continue::
    end
end

---@param event EventData.on_surface_renamed
function gui_handler.surface_renamed(event)
    for _, player in pairs(game.players) do
        local frame = gui.get_main(player)

        if not frame or not frame.valid then
            goto continue
        end

        local surface_selection = frame["title_bar"]["surface_select"] --[[@as LuaGuiElement]]

        for i, old_name in ipairs(surface_selection.items) do --[[@cast i uint]]
            if old_name == event.old_name then
                surface_selection.set_item(i, event.new_name)
                break
            end
        end

        ::continue::
    end
end

---@param event EventData.on_player_changed_surface
function gui_handler.player_changed_surfaces(event)
    local player = game.players[event.player_index]
    local frame = gui.get_main(player)

    if not frame or not frame.valid then
        return
    end

    local surface_selection = frame["title_bar"]["surface_select"] --[[@as LuaGuiElement]]
    local surface_name = player.surface.name

    for i, name in ipairs(surface_selection.items) do --[[@cast i uint]]
        if name == surface_name then
            surface_selection.selected_index = i
            break
        end
    end

    handlers.selected_new_surface(player, surface_selection)
end

---@param event EventData.on_player_removed
function gui_handler.player_removed(event)
    global.gui_selected_surface[event.player_index] = nil
end

---@param event EventData.on_gui_closed
function gui_handler.close(event)
    if not event.element then
        return
    end

    if event.element.name == gui.builder.mainFrameName then
        event.element.visible = false

        local player = game.players[event.player_index]
        local preferences = gui.get_preferences(player)

        if preferences then
            preferences.visible = false
        end

    end
end

return gui_handler