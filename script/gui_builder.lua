mod_gui = require("mod-gui")

local gui_builder = {}

-- CONSTANTS
gui_builder.flowButtonName = "CT_toggle_gui"
gui_builder.mainFrameName = "CT_main_guiFrame"
gui_builder.preferencesFrameName = "CT_preferences_guiFrame"


local function titleBar(frame, isMainFrame)
    local bar = frame.add{
        type = "flow"
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
        style = "ct_title_dragbar",
        ignored_by_interaction = true
    }

    if isMainFrame then
        -- surface selection
        bar.add{
            type = "drop-down",
            name = "surface_select",
            style = "ct_frame_dropdown",
            selected_index = 1,
            items = {
                "Nauvis"
            },
            tags = {
                mod = "constructron",
                on_gui_selection_state_changed = "update_surface"
            }
        }

        -- preference button
        bar.add{
            type = "button",
            style = "ct_frame_button",
            name = "title_preference",
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
        name = "title_close",
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

local function buildTabContent(name, tab_flow)
    local entityListFrame = tab_flow.add{
        type = "frame",
        name = "entity_list_frame",
        direction = "vertical",
        style = "deep_frame_in_shallow_frame"
    }
    entityListFrame.style.maximal_height = 750
    entityListFrame.style.vertically_stretchable = true

    local noEntityFrame = entityListFrame.add{
        type = "frame",
        name = "no_entity_frame",
        style = "negative_subheader_frame"
    }

    local noEntityFlow = noEntityFrame.add{
        type = "flow",
        name = "no_entity_flow",
        direction = "horizontal",
        style = "centering_horizontal_flow"
    }
    noEntityFlow.style.horizontally_stretchable = true

    noEntityFlow.add{
        type = "label",
        name = "no_entity_label",
        caption = {"gui.tab-empty-warn", {"gui." .. name}, "Nauvis"}
    }

    local entityScroll = entityListFrame.add{
        type = "scroll-pane",
        name = "entity_scroll",
        style = "technology_list_scroll_pane"
    }
    entityScroll.style.vertically_stretchable = true
    entityScroll.style.horizontally_stretchable = true

    local entityTable = entityScroll.add{
        type = "table",
        name = "entity_table",
        column_count = 4,
        style = "technology_slot_table"
    }
    entityTable.style.vertically_stretchable = true
    entityTable.style.horizontally_stretchable = true
    --entityTable.style.width = 600
    --entityTable.style.height = 1000

    entityTable.add{
        type = "label",
        caption = "test A"
    }
    entityTable.add{
        type = "label",
        caption = "test B"
    }
    entityTable.add{
        type = "label",
        caption = "test C"
    }
    entityTable.add{
        type = "label",
        caption = "test D"
    }
end

local function buildTab(name, count, tabbed_pane)
    local tab = tabbed_pane.add{
        type = "tab",
        name = name .. "_tab",
        caption = {"gui.tab-" .. name}
    }
    if count < 1000 then
        tab.badge_text = "" .. count
    else
        tab.badge_text = "999+"
    end

    local tabFlow = tabbed_pane.add{
        type = "flow",
        name = name .. "_flow",
        direction = "horizontal",
        style = "inset_frame_container_horizontal_flow_in_tabbed_pane"
    }

    tabbed_pane.add_tab(tab, tabFlow)

    buildTabContent(name, tabFlow)
end

local function buildMainContent(frame)
    local mainFlow = frame.add{
        type = "flow",
        name = "main_flow",
        direction = "horizontal"
    }
    --mainFlow.style.horizontal_spacing = 12
    --mainFlow.style.vertically_stretchable = true
    --mainFlow.style.horizontally_stretchable = true

    --[[
    local sideFlow = mainFlow.add{
        type = "flow",
        name = "side_flow",
        direction = "vertical"
    }
    sideFlow.style.vertical_spacing = 12

    local topSideFrame = sideFlow.add{
        type = "frame",
        name = "top_side_frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding"
    }
    topSideFrame.style.width = 250
    topSideFrame.style.height = 150
    topSideFrame.style.vertically_stretchable = true

    local bottomSideFrame = sideFlow.add{
        type = "frame",
        name = "bottom_side_frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding"
    }
    bottomSideFrame.style.horizontally_stretchable = true
    bottomSideFrame.style.height = 200
    --]]

    local tabPaneFrame = mainFlow.add{
        type = "frame",
        name = "tab_pane_frame",
        style = "inside_deep_frame_for_tabs"
    }
    tabPaneFrame.style.height = 350
    --tabPaneFrame.style.vertically_stretchable = true
    --tabPaneFrame.style.horizontally_stretchable = true

    local tabbedPane = tabPaneFrame.add{
        type = "tabbed-pane",
        name = "tabbed_pane"
    }
    --tabbedPane.style.vertically_stretchable = true
    --tabbedPane.style.horizontally_stretchable = true

    buildTab("idle", 0, tabbedPane)
    buildTab("construction", 420, tabbedPane)
    buildTab("deconstruction", 1337, tabbedPane)
    buildTab("upgrade", 69, tabbedPane)
    buildTab("repair", 42, tabbedPane)
end

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

function gui_builder.buildPreferencesGui(player)
    local frame = player.gui.screen.add{
        type = "frame",
        name = gui_builder.preferencesFrameName,
        direction = "vertical"
    }
    frame.auto_center = true

    titleBar(frame, false)
end

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

return gui_builder
