 local gui_job = {}


 function gui_job.buildJobGui(player, job)
    local job_window = player.gui.screen.add{
        type="frame",
        name="ctron_job_window",
        direction = "vertical",
        tags = {
            mod = "constructron",
            job_index = job.job_index
        }
    }
    job_window.auto_center = true

    gui_job.buildJobTitleBar(player, job_window)

    local job_inner_frame = job_window.add{
        type = "frame",
        name = "ctron_job_inner_frame",
        style = "ctron_job_inner_frame_style",
        direction = "vertical"
    }

    gui_job.buildJobContent(player, job_inner_frame, job)
end

function gui_job.buildJobTitleBar(player, frame)
    local bar = frame.add{
        type = "flow",
        name = "ctron_title_bar",
        style = "ctron_title_bar_flow_style",
    }
    bar.drag_target = frame

    -- title
    bar.add{
        type = "label",
        style = "frame_title",
        caption = {"ctron_gui_locale.job_title"},
        ignored_by_interaction = true
    }

    -- drag area
    bar.add{
        type = "empty-widget",
        style = "ctron_title_bar_drag_bar_style",
        ignored_by_interaction = true
    }

    -- close button
    bar.add{
        type = "sprite-button",
        name = "close_job_window",
        style = "frame_action_button",
        sprite = "utility/close",
        mouse_button_filter = {"left"},
        tags = {
            mod = "constructron",
            on_gui_click = "close_job_window"
        }
    }
end

function gui_job.buildJobContent(player, frame, job)
    local job_index = job.job_index
    local worker = job.worker
    if not worker or not worker.valid then
        frame.parent.destroy()
        player.print("Worker is invalid. A new Constructron will be assigned to this job when one becomes available") -- TODO: refactor this behavior
        return
    end

    local table = frame.add{
        type = "table",
        name = "ctron_job_table",
        column_count = 2,
    }

    -- left pane
    local left_pane = table.add{
        type = "frame",
        name = "ctron_job_left_pane",
        style = "ctron_job_left_pane_style",
        direction = "vertical"
    }

    -- control buttons
    local controls_flow = left_pane.add{
        type = "flow",
        name = "ctron_controls_flow",
        direction = "horizontal",
    }

    -- add remote button
    controls_flow.add{
        type = "button",
        name = "ctron_remote_button",
        caption = {"ctron_gui_locale.job_remote_button"},
        style = "ctron_frame_button_style",
        tooltip = {"ctron_gui_locale.job_remote_button_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_click = "ctron_remote_control",
            worker = worker.unit_number
        }
    }

    -- add cancel button
    controls_flow.add{
        type = "button",
        name = "ctron_cancel_button",
        caption = {"ctron_gui_locale.job_cancel_button"},
        style = "ctron_frame_button_style",
        tooltip = {"ctron_gui_locale.job_cancel_button_tooltip"},
        tags = {
            mod = "constructron",
            on_gui_click = "ctron_cancel_job",
            job_screen = true,
            job_index = job_index
        }
    }

    left_pane.add{
        type = "line",
        direction = "horizontal",
        ignored_by_interaction = true
    }

    -- worker minimap label
    left_pane.add{
        type = "label",
        name = "ctron_worker_minimap_label",
        caption = {"ctron_gui_locale.job_worker_minimap_label"}
    }

    -- add minimap for worker
    local worker_minimap_frame = left_pane.add{
        type = "frame",
        name = "ctron_worker_minimap_frame",
        style = "minimap_frame",
        direction = "vertical"
    }

    storage.user_interface[player.index].job_ui.elements["worker_minimap"] = worker_minimap_frame.add{
        type = "minimap",
        name = "ctron_worker_minimap",
        style = "ctron_minimap_style",
        tooltip = {"ctron_gui_locale.job_worker_minimap_tooltip"},
        zoom = 2,
        surface_index = job.surface_index,
        tags = {
            mod = "constructron",
            on_gui_click = "ctron_map_view",
            job_index = job.job_index,
            follow_entity = true
        }
    }
    storage.user_interface[player.index].job_ui.elements["worker_minimap"].entity = job.worker

    left_pane.add{
        type = "line",
        direction = "horizontal",
        ignored_by_interaction = true
    }

    -- job minimap label
    left_pane.add{
        type = "label",
        name = "ctron_job_minimap_label",
        caption = {"ctron_gui_locale.job_job_minimap_label"},
    }

    -- add minimap for job
    local job_minimap_frame = left_pane.add{
        type = "frame",
        name = "ctron_job_minimap_frame",
        style = "minimap_frame",
        direction = "vertical"
    }

    storage.user_interface[player.index].job_ui.elements["job_minimap"] = job_minimap_frame.add{
        type = "minimap",
        name = "ctron_job_minimap",
        style = "ctron_minimap_style",
        tooltip = {"ctron_gui_locale.job_job_minimap_tooltip"},
        zoom = 2,
        surface_index = job.surface_index,
        position = (job.task_positions[1] or job.station.position or job.worker.position),
        tags = {
            mod = "constructron",
            on_gui_click = "ctron_map_view",
            job_index = job.job_index,
            follow_entity = false
        }
    }

    -- job stats
    storage.user_interface[player.index].job_ui.elements["job_tasks_stat_label"] = left_pane.add{
        type = "label",
        name = "ctron_job_stats_label_1",
        caption = {"ctron_gui_locale.job_job_stat_tasks_label", (#job.task_positions or "0")}
    }

    -- right pane
    local right_pane = table.add{
        type = "frame",
        name = "ctron_job_right_pane",
        style = "ctron_job_right_pane_style",
        direction = "vertical"
    }

    -- ammo display
    right_pane.add{
        type = "label",
        name = "ctron_ammo_label",
        caption = {"ctron_gui_locale.job_worker_ammo_label"},
    }
    storage.user_interface[player.index].job_ui.elements["ammo_table"] = right_pane.add{
        type = "table",
        name = "ctron_ammo_table",
        style = "ctron_ammo_table_style",
        column_count = 10,
    }
    gui_job.build_ammo_display(worker, storage.user_interface[player.index].job_ui.elements["ammo_table"])

    -- inventory display
    -- label
    right_pane.add{
        type = "label",
        name = "ctron_inventory_label",
        caption = {"ctron_gui_locale.job_worker_inventory_label"},
    }

    local inventory_scroll_pane = right_pane.add{
        type = "scroll-pane",
        name = "ctron_inventory_scroll_pane",
        direction = "vertical"
    }
    inventory_scroll_pane.style.maximal_height = 320

    storage.user_interface[player.index].job_ui.elements["inventory_table"] = inventory_scroll_pane.add{
        type = "table",
        name = "ctron_inventory_table",
        style = "slot_table",
        column_count = 10,
    }

    gui_job.build_inventory_display(worker, storage.user_interface[player.index].job_ui.elements["inventory_table"])

    -- empty widget
    table.add{
        type = "empty-widget",
        name = "ctron_empty_widget_1",
        ignored_by_interaction = true
    }

    -- trash display
    -- label
    right_pane.add{
        type = "label",
        name = "ctron_trash_label",
        caption = {"ctron_gui_locale.job_worker_logistic_trash_label"},
    }

    local trash_scroll_pane = right_pane.add{
        type = "scroll-pane",
        name = "ctron_trash_scroll_pane",
        direction = "vertical"
    }
    trash_scroll_pane.style.minimal_height = 80

    storage.user_interface[player.index].job_ui.elements["trash_table"] = trash_scroll_pane.add{
        type = "table",
        name = "ctron_trash_table",
        style = "slot_table",
        column_count = 10,
    }

    gui_job.build_trash_display(worker, storage.user_interface[player.index].job_ui.elements["trash_table"])

    -- empty widget
    table.add{
        type = "empty-widget",
        name = "ctron_empty_widget_2",
        ignored_by_interaction = true
    }

    -- logistics display
    -- label
    right_pane.add{
        type = "label",
        name = "ctron_logistic_label",
        caption = {"ctron_gui_locale.job_worker_logistic_requests_label"},
    }

    local logistic_scroll_pane = right_pane.add{
        type = "scroll-pane",
        name = "ctron_logistic_scroll_pane",
        direction = "vertical",
        style = "deep_slots_scroll_pane"
    }

    storage.user_interface[player.index].job_ui.elements["logistic_table"] = logistic_scroll_pane.add{
        type = "table",
        name = "ctron_logistic_table",
        style = "filter_slot_table",
        column_count = 10,
    }

    gui_job.build_logistic_display(worker, storage.user_interface[player.index].job_ui.elements["logistic_table"])
end

function gui_job.build_ammo_display(worker, ammo_table)
    local ammo_inventory = worker.get_inventory(defines.inventory.spider_ammo)
    for i = 1, #ammo_inventory do
        local ammo = ammo_inventory[i]
        if ammo and ammo.valid_for_read then
            gui_job.build_button(ammo_table, "ctron_ammo_button_" .. i, ammo.name, ammo.quality.name, ammo.count, "inventory_slot")
        else
            local button = ammo_table.add{
                type = "sprite-button",
                name = "ctron_ammo_button_" .. i,
                style = "inventory_slot",
                sprite = "utility/empty_ammo_slot",
                tags = {
                    mod = "constructron",
                }
            }
            button.style.padding = 2
        end
    end
end

function gui_job.build_inventory_display(worker, inventory_table)
    -- get worker inventory items
    local inventory = worker.get_inventory(defines.inventory.spider_trunk)
    for i = 1, #inventory do
        local item = inventory[i]
        if item and item.valid_for_read then
            -- add inventory item button
            gui_job.build_button(inventory_table, "ctron_inventory_button_" .. i, item.name, item.quality.name, item.count, "inventory_slot")
        else
            inventory_table.add{
                type = "sprite-button",
                name = "ctron_inventory_button_" .. i,
                style = "inventory_slot",
                tags = {
                    mod = "constructron",
                }
            }
        end
    end
end

function gui_job.build_trash_display(worker, trash_table)
    -- get worker trash inventory items
    local trash_inventory = worker.get_inventory(defines.inventory.spider_trash)
    for i = 1, #trash_inventory do
        local item = trash_inventory[i]
        if item and item.valid_for_read then
            gui_job.build_button(trash_table, "ctron_trash_button_" .. i, item.name, item.quality.name, item.count, "inventory_slot")
        else
            local button = trash_table.add{
                type = "sprite-button",
                name = "ctron_trash_button_" .. i,
                style = "inventory_slot",
                sprite = "utility/trash_white",
                tags = {
                    mod = "constructron",
                }
            }
            button.style.padding = 8
        end
    end
end

function gui_job.build_logistic_display(worker, logistic_table)
    -- get worker logistic requests
    local logistic_point = worker.get_logistic_point(0) ---@cast logistic_point -nil
    local section = logistic_point.get_section(1)
    local slot_count = #(section.filters or {})
    -- Ensure the value is at least 10
    local min_slot_count = math.max(slot_count, 10)
    -- Round up to the nearest 20
    local logistic_request_count = math.ceil(min_slot_count / 20) * 20
    for i = 1, logistic_request_count do
        if section.filters[i] and section.filters[i].value then
            local slot = section.filters[i]
            local slot_item = slot.value
            gui_job.build_button(logistic_table, "ctron_logistic_button_" .. i, slot_item.name, slot_item.quality, slot.max or slot.min, nil, worker)
        else
            logistic_table.add{
                type = "sprite-button",
                name = "ctron_logistic_button_" .. i,
                style = "slot_button",
                tags = {
                    mod = "constructron",
                }
            }
        end
    end
end

---@param parent LuaGuiElement
---@param name string
---@param item string
---@param quality string
---@param count number
---@param style string?
---@param worker LuaEntity?
function gui_job.build_button(parent, name, item, quality, count, style, worker)
    local button = parent.add{
        type = "choose-elem-button",
        name = name,
        elem_type = "item-with-quality",
        ["item-with-quality"] = {name = item, quality = quality},
        style = style,
        elem_tooltip = {
            type = "item",
            name = item
        },
        tags = {
            mod = "constructron",
            on_gui_click = "clear_logistic_request",
        }
    }
    if worker then
        local tags = button.tags
        tags["unit_number"] = worker.unit_number
        button.tags = tags
    end
    button.locked = true
    -- add flow to button
    local flow = button.add{
        type = "flow",
        style = "ctron_cargo_flow_style",
        direction = "horizontal",
        ignored_by_interaction = true
    }
    flow.style.height = 33
    flow.style.width = 33
    flow.style.horizontally_stretchable = false
    -- add label to flow
    local ew = flow.add{
        type = "empty-widget",
    }
    ew.style.horizontally_stretchable = true
    -- add item count label
    flow.add{
        type = "label",
        style = "ctron_cargo_item_label_style",
        caption = count
    }
end

return gui_job