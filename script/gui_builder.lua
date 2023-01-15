mod_gui = require("mod-gui")

---@class GUIBuilder
local gui_builder = {}

-- CONSTANTS
gui_builder.flowButtonName = "CTRON_toggle_gui"
gui_builder.mainFrameName = "CTRON_main_guiFrame"
--gui_builder.preferencesFrameName = "CTRON_preferences_guiFrame"

---@param frame LuaGuiElement
---@param isMainFrame boolean
local function titleBar(frame, isMainFrame)
    local bar = frame.add{
        type = "flow",
        name = "title_bar",
        style = "ctron_title_bar_flow"
    }
    bar.drag_target = frame

    local title
    local close_callback
    if isMainFrame then
        title = {"gui.main-title"}
        close_callback = "toggle_main"
--    else
--        title = {"gui.preferences-title"}
--        close_callback = "toggle_preferences"
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
        --[[bar.add{
            type = "button",
            style = "ctron_frame_button",
            name = "preference_button",
            caption = {"gui.preferences"},
            mouse_button_filter = {"left"},
            tags = {
                mod = "constructron",
                on_gui_click = "toggle_preferences"
            }
        }]]

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
        style = "ctron_entity_list_frame"
    }

    local noEntityFrame = entityListFrame.add{
        type = "frame",
        name = "no_entity",
        style = "negative_subheader_frame"
    }

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
    entityScroll.horizontal_scroll_policy = "never"
    entityScroll.vertical_scroll_policy = "auto-and-reserve-space"

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
        style = "ctron_tab_flow"
    }

    tabbed_pane.add_tab(tab, tabFlow)

    buildTabContent(name, tabFlow)
end

---@param frame LuaGuiElement
local function buildMainContent(frame)
    local tabPaneFrame = frame.add{
        type = "frame",
        name = "main",
        style = "ctron_tab_pane_frame"
    }

    local tabbedPane = tabPaneFrame.add{
        type = "tabbed-pane",
        name = "tab_pane",
        style = "ctron_tabbed_pane",
        tags = {
            mod = "constructron",
            on_gui_selected_tab_changed  = "update_tab_content"
        }
    }

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

    titleBar(frame, true)
    buildMainContent(frame)
end

--@param player LuaPlayer
--[[function gui_builder.buildPreferencesGui(player)
    local frame = player.gui.screen.add{
        type = "frame",
        name = gui_builder.preferencesFrameName,
        direction = "vertical"
    }
    frame.auto_center = true

    titleBar(frame, false)
end]]

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
        style = "ctron_entity_item_map_button",
        tags = {
            mod = "constructron",
            on_gui_click = "open_ctron_map",
            unit = constructron.unit_number,
        }
    }

    local minimap = button.add{
        type = "minimap",
        name = "map",
        ignored_by_interaction = true,
        style = "ctron_entity_item_map"
    }
    minimap.entity = constructron
    minimap.zoom = 1.25

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
        style = "ctron_entity_item_inventory_frame"
    }

    local inventory = right.add{
        type = "table",
        name = "inventory",
        column_count = 7,
        style = "ctron_entity_item_inventory_table"
    }

    local c_inv = constructron.get_inventory(defines.inventory.spider_trunk)
    local c_trash = constructron.get_inventory(defines.inventory.spider_trash)

    if c_inv and c_trash then
        local items = c_inv.get_contents()
        local trash = c_trash.get_contents()
        local combined_inv = {none = {}, done = {}, requesting = {}, dumping = {}}

        -- parsing regular inventory
        for name, count in pairs(items) do
            combined_inv.none[name] = {count = count}
        end

        -- parsing trash inventory
        for name, count in pairs(trash) do
            combined_inv.dumping[name] = {count = count}
        end

        -- parsing logistic requests
        for slot = 1, constructron.request_slot_count do --[[@cast slot uint]]
            local req_slot = constructron.get_vehicle_logistic_slot(slot)
            local name = req_slot.name

            if not name then
                goto continue
            end

            local none_tmp = combined_inv.none[name]

            -- dumping items out of inventory?
            if req_slot.min == 0 then
                local dump_tmp = combined_inv.dumping[name]
                if none_tmp and dump_tmp then
                    none_tmp.count = none_tmp.count + dump_tmp.count
                end

                combined_inv.dumping[name] = none_tmp or dump_tmp or {count = 0}
                combined_inv.none[name] = nil

                goto continue
            end

            -- requesting the item (or already completed)
            if none_tmp then
                if none_tmp.count >= req_slot.min then
                    combined_inv.done[name] = none_tmp
                else
                    combined_inv.requesting[name] = {
                        count = req_slot.min - none_tmp.count,
                        tags = {
                            mod = "constructron",
                            on_gui_click = "remove_logistic_request",
                            unit = constructron.unit_number,
                            slot = slot
                        }
                    }
                end

                combined_inv.none[name] = nil
            else
                combined_inv.requesting[name] = {
                    count = req_slot.min,
                    tags = {
                        mod = "constructron",
                        on_gui_click = "remove_logistic_request",
                        unit = constructron.unit_number,
                        slot = slot
                    }
                }
            end

            ::continue::
        end

        local inv_max_size = 7*7
        local style_per_type = {
            none = "flib_slot_button_default",
            done = "flib_slot_button_green",
            requesting = "flib_slot_button_orange",
            dumping = "flib_slot_button_red"
        }

        -- building inventory items
        for sub_type, sub_list in pairs(combined_inv) do
            local style = style_per_type[sub_type]

            for name, data in pairs(sub_list) do
                inventory.add{
                    type = "sprite-button",
                    name = name,
                    sprite = "item/" .. name,
                    number = data.count,
                    style = style,
                    tags = data.tags or {
                        mod = "constructron"
                    }
                }

                -- is inventory full?
                if #inventory.children_names >= inv_max_size then
                    goto inventory_complete
                end
            end
        end

        ::inventory_complete::
    end
end

return gui_builder
