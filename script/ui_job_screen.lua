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
        sprite = "utility/close_white",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
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

    global.user_interface[player.index].job_ui.elements["worker_minimap"] = worker_minimap_frame.add{
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
    global.user_interface[player.index].job_ui.elements["worker_minimap"].entity = job.worker

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

    global.user_interface[player.index].job_ui.elements["job_minimap"] = job_minimap_frame.add{
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
    global.user_interface[player.index].job_ui.elements["job_tasks_stat_label"] = left_pane.add{
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
    global.user_interface[player.index].job_ui.elements["ammo_table"] = right_pane.add{
        type = "table",
        name = "ctron_ammo_table",
        style = "ctron_ammo_table_style",
        column_count = 10,
    }
    gui_job.build_ammo_display(worker, global.user_interface[player.index].job_ui.elements["ammo_table"])

    -- inventory display
    local inventory_scroll_pane = right_pane.add{
        type = "scroll-pane",
        name = "ctron_inventory_scroll_pane",
        direction = "vertical"
    }

    -- label
    inventory_scroll_pane.add{
        type = "label",
        name = "ctron_inventory_label",
        caption = {"ctron_gui_locale.job_worker_inventory_label"},
    }

    global.user_interface[player.index].job_ui.elements["inventory_table"] = inventory_scroll_pane.add{
        type = "table",
        name = "ctron_inventory_table",
        style = "ctron_inventory_table_style",
        column_count = 10,
    }

    gui_job.build_inventory_display(worker, global.user_interface[player.index].job_ui.elements["inventory_table"])

    -- empty widget
    table.add{
        type = "empty-widget",
        name = "ctron_empty_widget_1",
        ignored_by_interaction = true
    }

    -- trash display
    local trash_scroll_pane = right_pane.add{
        type = "scroll-pane",
        name = "ctron_trash_scroll_pane",
        direction = "vertical"
    }

    -- label
    trash_scroll_pane.add{
        type = "label",
        name = "ctron_trash_label",
        caption = {"ctron_gui_locale.job_worker_logistic_trash_label"},
    }

    global.user_interface[player.index].job_ui.elements["trash_table"] = trash_scroll_pane.add{
        type = "table",
        name = "ctron_trash_table",
        style = "ctron_trash_table_style",
        column_count = 10,
    }

    gui_job.build_trash_display(worker, global.user_interface[player.index].job_ui.elements["trash_table"])

    -- empty widget
    table.add{
        type = "empty-widget",
        name = "ctron_empty_widget_2",
        ignored_by_interaction = true
    }

    -- logistics display
    local logistic_scroll_pane = right_pane.add{
        type = "scroll-pane",
        name = "ctron_logistic_scroll_pane",
        direction = "vertical"
    }

    -- label
    logistic_scroll_pane.add{
        type = "label",
        name = "ctron_logistic_label",
        caption = {"ctron_gui_locale.job_worker_logistic_requests_label"},
    }

    local logistic_inner_frame = logistic_scroll_pane.add{
        type = "frame",
        name = "ctron_logistic_inner_frame",
        style = "inside_deep_frame",
        direction = "vertical"
    }

    global.user_interface[player.index].job_ui.elements["logistic_table"] = logistic_inner_frame.add{
        type = "table",
        name = "ctron_logistic_table",
        style = "ctron_logistic_table_style",
        column_count = 10,
    }

    gui_job.build_logistic_display(worker, global.user_interface[player.index].job_ui.elements["logistic_table"])
end

function gui_job.build_ammo_display(worker, ammo_table)
    local ammo_inventory = worker.get_inventory(defines.inventory.spider_ammo)
    for i = 1, #ammo_inventory do
        local ammo = ammo_inventory[i]
        if ammo and ammo.valid_for_read then
            ammo_table.add{
                type = "sprite-button",
                name = "ctron_ammo_button_" .. i,
                style = "inventory_slot",
                tooltip = ammo.name,
                sprite = "item/" .. ammo.name,
                number = ammo.count,
                tags = {
                    mod = "constructron",
                }
            }
        else
            local button = ammo_table.add{
                type = "sprite-button",
                name = "ctron_ammo_button_" .. i,
                style = "inventory_slot",
                sprite = "utility/slot_icon_ammo",
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
            inventory_table.add{
                type = "sprite-button",
                name = "ctron_inventory_button_" .. i,
                style = "inventory_slot",
                tooltip = item.name,
                sprite = "item/" .. item.name,
                number = item.count,
                tags = {
                    mod = "constructron",
                }
            }
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
            trash_table.add{
                type = "sprite-button",
                name = "ctron_inventory_button_" .. i,
                style = "inventory_slot",
                tooltip = item.name,
                sprite = "item/" .. item.name,
                number = item.count,
                tags = {
                    mod = "constructron",
                }
            }
        else
            local button = trash_table.add{
                type = "sprite-button",
                name = "ctron_inventory_button_" .. i,
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
    local slot_count = worker.request_slot_count
    -- Ensure the value is at least 10
    min_slot_count = math.max(slot_count, 10)
    -- Round up to the nearest 20
    logistic_request_count = math.ceil(min_slot_count / 20) * 20
    for i = 1, logistic_request_count do
        local slot = worker.get_vehicle_logistic_slot(i)
        if slot.name ~= nil then
            logistic_table.add{
                type = "sprite-button",
                name = "ctron_logistic_button_" .. i,
                style = "logistic_slot_button",
                tooltip = slot.name,
                sprite = "item/" .. slot.name,
                number = slot.max,
                tags = {
                    mod = "constructron",
                    on_gui_click = "clear_logistic_request",
                    logistic_slot = i,
                    unit_number = worker.unit_number,
                    -- job_index = job.job_index
                }
            }
        else
            logistic_table.add{
                type = "sprite-button",
                name = "ctron_logistic_button_" .. i,
                style = "logistic_slot_button",
                tags = {
                    mod = "constructron",
                }
            }
        end
    end
end

return gui_job