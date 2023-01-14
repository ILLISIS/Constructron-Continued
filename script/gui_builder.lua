mod_gui = require("mod-gui")

---@class GUIBuilder
local gui_builder = {}

-- CONSTANTS
gui_builder.flowButtonName = "CTRON_toggle_gui"
gui_builder.mainFrameName = "CTRON_main_guiFrame"
gui_builder.preferencesFrameName = "CTRON_preferences_guiFrame"

---@param frame LuaGuiElement
---@param isMainFrame boolean
local function titleBar(frame, isMainFrame)
    local bar = frame.add{
        type = "flow",
        name = "title_bar"
    }
    bar.drag_target = frame
    bar.style.horizontal_spacing = 8
    bar.style.height = 28

    local title
    local close_callback
    if isMainFrame then
        title = {"gui.main-title"}
        close_callback = "toggle_main"
    else
        title = {"gui.preferences-title"}
        close_callback = "toggle_preferences"
    end

    -- title
    bar.add{
        type = "label",
        style = "frame_title",
        caption = title,
        ignored_by_interaction = true
    }

    -- drag area
    bar.add{
        type = "empty-widget",
        style = "ctron_title_dragbar",
        ignored_by_interaction = true
    }

    if isMainFrame then

        -- surface selection
        local surfaces = {}

        for _, surface in pairs(game.surfaces) do
            surfaces[#surfaces+1] = surface.name
        end

        bar.add{
            type = "drop-down",
            name = "surface_select",
            style = "ctron_frame_dropdown",
            selected_index = 1,
            visible = (#surfaces > 1),
            items = surfaces,
            tags = {
                mod = "constructron",
                on_gui_selection_state_changed = "selected_new_surface"
            }
        }

        -- preference button
        bar.add{
            type = "button",
            style = "ctron_frame_button",
            name = "preference_button",
            caption = {"gui.preferences"},
            mouse_button_filter = {"left"},
            tags = {
                mod = "constructron",
                on_gui_click = "toggle_preferences"
            }
        }

        -- seperator line
        local seperator = bar.add{
            type = "line",
            direction = "vertical",
            ignored_by_interaction = true
        }
        seperator.style.height = 24
    end

    -- close button
    bar.add{
        type = "sprite-button",
        name = "close_button",
        style = "frame_action_button",
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = close_callback
        }
    }
end

---@param name string
---@param tab_flow LuaGuiElement
local function buildTabContent(name, tab_flow)
    local entityListFrame = tab_flow.add{
        type = "frame",
        name = "frame",
        direction = "vertical",
        style = "deep_frame_in_shallow_frame"
    }
    --entityListFrame.style.maximal_height = 750
    --entityListFrame.style.horizontally_stretchable = true
    --entityListFrame.style.vertically_stretchable = true

    local noEntityFrame = entityListFrame.add{
        type = "frame",
        name = "no_entity",
        style = "negative_subheader_frame"
    }
    --noEntityFrame.style.bottom_margin = -36

    local noEntityFlow = noEntityFrame.add{
        type = "flow",
        name = "flow",
        direction = "horizontal",
        style = "centering_horizontal_flow"
    }
    noEntityFlow.style.horizontally_stretchable = true

    noEntityFlow.add{
        type = "label",
        name = "label",
        caption = {"gui.tab-empty-warn", {"gui." .. name}, "nauvis"}
    }

    local scroll_style = "ctron_entity_scroll"
    if name == "idle" then
        scroll_style = "ctron_idle_entity_scroll"
    end
    local entityScroll = entityListFrame.add{
        type = "scroll-pane",
        name = "scroll",
        style = scroll_style
    }
    --entityScroll.style.vertically_stretchable = true
    --entityScroll.style.horizontally_stretchable = true
    --entityScroll.style.height = 912
    --entityScroll.style.minimal_height = 710
    entityScroll.horizontal_scroll_policy = "never"
    entityScroll.vertical_scroll_policy = "auto-and-reserve-space"
    --entityScroll.style.vertically_squashable = true
    --entityScroll.style.extra_padding_when_activated = 0

    local col_count = 2 ---@type uint
    if name == "idle" then
        col_count = 4
    end

    local entityTable = entityScroll.add{
        type = "table",
        name = "table",
        column_count = col_count,
        style = "ctron_entity_table"
    }
    --entityTable.style.vertically_stretchable = true
    --entityTable.style.horizontally_stretchable = true
    --entityTable.style.horizontal_spacing = 0
    --entityTable.style.vertical_spacing = 0
    --entityTable.style.width = 1168 -- 4 * 292 (width of 1 idle item)
end

---@param name string
---@param count uint
---@param tabbed_pane LuaGuiElement
local function buildTab(name, count, tabbed_pane)
    local tab = tabbed_pane.add{
        type = "tab",
        name = name .. "_tab",
        caption = {"gui.tab-" .. name},
        tags = {
            tab_type = name
        }
    }
    if count < 1000 then
        tab.badge_text = count
    else
        tab.badge_text = "999+"
    end

    local tabFlow = tabbed_pane.add{
        type = "flow",
        name = name .. "_flow",
        direction = "horizontal",
        style = "inset_frame_container_horizontal_flow_in_tabbed_pane"
    }
    tabFlow.style.horizontally_stretchable = true
    tabFlow.style.vertically_stretchable = true

    tabbed_pane.add_tab(tab, tabFlow)

    buildTabContent(name, tabFlow)
end

---@param frame LuaGuiElement
local function buildMainContent(frame)
    local tabPaneFrame = frame.add{
        type = "frame",
        name = "main",
        style = "inside_deep_frame_for_tabs"
    }
    --tabPaneFrame.style.height = 350
    tabPaneFrame.style.vertically_stretchable = true
    tabPaneFrame.style.horizontally_stretchable = true

    local tabbedPane = tabPaneFrame.add{
        type = "tabbed-pane",
        name = "tab_pane",
        tags = {
            mod = "constructron",
            on_gui_selected_tab_changed  = "update_tab_content"
        }
    }
    tabbedPane.style.vertically_stretchable = true
    tabbedPane.style.horizontally_stretchable = true

    buildTab("idle", 0, tabbedPane)
    buildTab("construct", 420, tabbedPane)
    buildTab("deconstruct", 1337, tabbedPane)
    buildTab("upgrade", 69, tabbedPane)
    buildTab("repair", 42, tabbedPane)

    tabbedPane.selected_tab_index = 1
end

---@param player LuaPlayer
function gui_builder.buildMainGui(player)
    local frame = player.gui.screen.add{
        type = "frame",
        name = gui_builder.mainFrameName,
        direction = "vertical"
    }
    frame.auto_center = true
    --frame.style.horizontally_stretchable = true
    --frame.style.vertically_stretchable = true
    frame.style.width = 1228
    frame.style.height = 834

    titleBar(frame, true)
    buildMainContent(frame)
end

---@param player LuaPlayer
function gui_builder.buildPreferencesGui(player)
    local frame = player.gui.screen.add{
        type = "frame",
        name = gui_builder.preferencesFrameName,
        direction = "vertical"
    }
    frame.auto_center = true

    titleBar(frame, false)
end

---@param buttonFlow LuaGuiElement
function gui_builder.buildModGuiButton(buttonFlow)
    buttonFlow.add{
        type = "button",
        name = gui_builder.flowButtonName,
        caption = "CT",
        tooltip = "Toggle the Constructron interface",
        mouse_button_filter = {"left"},
        visibility = true,
        style = mod_gui.button_style,
        tags = {
            mod = "constructron",
            on_gui_click = "toggle_main"
        }
    }
end

---@param entity_list LuaGuiElement
---@param constructron LuaEntity
---@param is_idle boolean
function gui_builder.buildItem(entity_list, constructron, is_idle)
    local frame = entity_list.add{
        type = "frame",
        name = "ctron_" .. constructron.unit_number,
        style = "train_with_minimap_frame",
        direction = "horizontal",
    }

    local left = frame.add{
        type = "flow",
        name = "left",
        direction = "vertical",
    }

    local button = left.add{
        type = "button",
        name = "map-button",
        style = "locomotive_minimap_button",
        tags = {
            mod = "constructron",
            on_gui_click = "open_ctron_map",
            unit = constructron.unit_number,
        }
    }
    button.style.height = 260 + 16 - 40
    button.style.width = 260 + 8

    local minimap = button.add{
        type = "minimap",
        name = "map",
        ignored_by_interaction = true
    }
    minimap.entity = constructron
    minimap.zoom = 1.25
    minimap.style.height = 260 + 16 - 40
    minimap.style.width = 260 + 8

    local left_bottom = left.add{
        type = "flow",
        direction = "horizontal",
        name = "bottom"
    }

    left_bottom.add{
        type = "sprite-button",
        name = "remote-button",
        sprite = "item/spidertron-remote",
        tags = {
            mod = "constructron",
            on_gui_click = "get_ctron_remote",
            unit = constructron.unit_number,
        },
        tooltip = "get a temporary remote\nfor this constructron"
    }

    left_bottom.add{
        type = "sprite-button",
        name = "recall-button",
        sprite = "item/service_station",
        tags = {
            mod = "constructron",
            on_gui_click = "recall_ctron",
            unit = constructron.unit_number,
        },
        enabled = not is_idle,
        tooltip = "cancel job and return home"
    }

    local right = frame.add{
        type = "frame",
        name = "right",
        direction = "vertical",
        visible = is_idle == false,
        style = "slot_button_deep_frame"
    }
    right.style.width = 280 -- 7 * 40 --260 + 12
    right.style.height = 280 -- 7 * 40 --304

    local inventory = right.add{
        type = "table",
        name = "inventory",
        column_count = 7
    }
    inventory.style.horizontal_spacing = 0
    inventory.style.vertical_spacing = 0

    local c_inv = constructron.get_inventory(defines.inventory.spider_trunk)

    if c_inv then
        local items = c_inv.get_contents()
        local c_req = {}

        for slot = 1, constructron.request_slot_count do --[[@cast slot uint]]
            local req_slot = constructron.get_vehicle_logistic_slot(slot)

            if req_slot.name ~= nil then
                local tmp = {}
                tmp.count = req_slot.min
                tmp.tags = {
                    mod = "constructron",
                    on_gui_click = "remove_logistic_request",
                    unit = constructron.unit_number,
                    slot = slot,
                }

                c_req[req_slot.name] = tmp
            end
        end

        for item, count in pairs(items) do
            local slot_style = "slot_button"
            local tags = {
                mod = "constructron"
            }

            if c_req[item] then
                local req_count = c_req[item].count
                slot_style = "red_slot_button"

                if req_count > 0 then
                    tags = c_req[item].tags
                    slot_style = "yellow_slot_button"
                end

                count = count - req_count
                c_req[item] = nil
            end

            inventory.add{
                type = "sprite-button",
                name = item,
                sprite = "item/" .. item,
                number = count,
                style = slot_style,
                tags = tags
            }

            if #inventory.children_names == (7*7) then
                goto inventory_complete
            end
        end

        for item, req in pairs(c_req) do
            local slot_style = "yellow_slot_button"

            if req.count == 0 then
                slot_style = "red_slot_button"
            end

            inventory.add{
                type = "sprite-button",
                name = item,
                sprite = "item/" .. item,
                number = -req.count,
                style = slot_style,
                tags = req.tags
            }

            if #inventory.children_names == (7*7) then
                goto inventory_complete
            end
        end
    end

    ::inventory_complete::

end

return gui_builder
