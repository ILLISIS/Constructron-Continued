local custom_lib = require("script/custom_lib")
local debug_lib = require("script/debug_lib")
local pathfinder = require("script/pathfinder")
local cmd = require("script/command_functions")
local entity_proc = require("script/entity_processor")
local job_proc = require("script/job_processor")

-- main workers
script.on_nth_tick(60, job_proc.process_job_queue)

script.on_nth_tick(15, function()
    if not global.entity_proc_trigger then return end -- trip switch to return early when there is nothing to process
    if next(global.deconstruction_entities) then -- deconstruction has priority over construction.
        entity_proc.add_entities_to_chunks("deconstruction", global.deconstruction_entities, global.deconstruct_queue, global.deconstruct_marked_tick)
    elseif next(global.ghost_entities) then
        entity_proc.add_entities_to_chunks("construction", global.ghost_entities, global.construct_queue, global.ghost_tick)
    elseif next(global.upgrade_entities) then
        entity_proc.add_entities_to_chunks("upgrade", global.upgrade_entities, global.upgrade_queue, global.upgrade_marked_tick)
    elseif next(global.repair_entities) then
        entity_proc.add_entities_to_chunks("repair", global.repair_entities, global.repair_queue, global.repair_marked_tick)
    else
        global.entity_proc_trigger = false -- stop entity processing
        global.queue_proc_trigger = true -- start job processing
    end
end)

-- cleanup
script.on_nth_tick(54000, (function()
    debug_lib.DebugLog('Surface job validation & cleanup')
    for s, surface in pairs(game.surfaces) do
        if (global.constructrons_count[surface.index] <= 0) or (global.stations_count[surface.index] <= 0) then
            debug_lib.DebugLog('No Constructrons or Service Stations found on ' .. surface.name)
            debug_lib.DebugLog('All job queues on '.. surface.name ..' cleared!')
            global.construct_queue[surface.index] = {}
            global.deconstruct_queue[surface.index] = {}
            global.upgrade_queue[surface.index] = {}
            global.repair_queue[surface.index] = {}
        end
    end
end))

--===========================================================================--
-- init
--===========================================================================--

local ensure_globals = function()
    global.registered_entities = global.registered_entities or {}
    global.constructron_statuses = global.constructron_statuses or {}
    --
    global.entity_proc_trigger = global.entity_proc_triggerr or false
    global.queue_proc_trigger = global.queue_proc_trigger or false
    global.job_proc_trigger = global.job_proc_trigger or false
    --
    global.managed_surfaces = global.managed_surfaces or {}
    --
    global.stack_cache = {} -- rebuild
    --
    global.job_bundle_index = global.job_bundle_index or 1
    --
    global.ghost_index = global.ghost_index or 0
    global.decon_index = global.decon_index or 0
    global.upgrade_index = global.upgrade_index or 0
    global.repair_index = global.repair_index or 0
    --
    global.ghost_entities = global.ghost_entities or {}
    global.deconstruction_entities = global.deconstruction_entities or {}
    global.upgrade_entities = global.upgrade_entities or {}
    global.repair_entities = global.repair_entities or {}
    --
    global.construct_queue = global.construct_queue or {}
    global.deconstruct_queue = global.deconstruct_queue or {}
    global.upgrade_queue = global.upgrade_queue or {}
    global.repair_queue = global.repair_queue or {}
    --
    global.job_bundles = global.job_bundles or {}
    --
    global.constructrons = global.constructrons or {}
    global.service_stations = global.service_stations or {}
    --
    global.constructrons_count = global.constructrons_count or {}
    global.stations_count = global.stations_count or {}
    --
    for s, surface in pairs(game.surfaces) do
        global.constructrons_count[surface.index] = global.constructrons_count[surface.index] or 0
        global.stations_count[surface.index] = global.stations_count[surface.index] or 0
        global.construct_queue[surface.index] = global.construct_queue[surface.index] or {}
        global.deconstruct_queue[surface.index] = global.deconstruct_queue[surface.index] or {}
        global.upgrade_queue[surface.index] = global.upgrade_queue[surface.index] or {}
        global.repair_queue[surface.index] = global.repair_queue[surface.index] or {}
    end
    -- build allowed items cache (used in add_entities_to_chunks)
    global.allowed_items = {}
    for item_name, _ in pairs(game.item_prototypes) do
        local recipes = game.get_filtered_recipe_prototypes({
                {filter = "has-product-item", elem_filters = {{filter = "name", name = item_name}}},
            })
        for _ , recipe in pairs(recipes) do
            if not game.forces["player"].recipes[recipe.name].hidden then -- if the recipe is hidden disallow it
                global.allowed_items[item_name] = true
            end
        end
        if global.allowed_items[item_name] == nil then -- some items do not have recipes so set the item to disallowed
            global.allowed_items[item_name] = false
        end
    end
    -- build required_items cache (used in add_entities_to_chunks)
    global.items_to_place_cache = {}
    for name, v in pairs(game.entity_prototypes) do
        if v.items_to_place_this ~= nil and v.items_to_place_this[1] and v.items_to_place_this[1].name then -- bots will only ever use the first item from this list
            global.items_to_place_cache[name] = {item = v.items_to_place_this[1].name, count = v.items_to_place_this[1].count}
        end
    end
    for name, v in pairs(game.tile_prototypes) do
        if v.items_to_place_this ~= nil and v.items_to_place_this[1] and v.items_to_place_this[1].name then -- bots will only ever use the first item from this list
            global.items_to_place_cache[name] = {item = v.items_to_place_this[1].name, count = v.items_to_place_this[1].count}
        end
    end
    -- settings
    global.construction_job_toggle = settings.global["construct_jobs"].value
    global.rebuild_job_toggle = settings.global["rebuild_jobs"].value
    global.deconstruction_job_toggle = settings.global["deconstruct_jobs"].value
    global.upgrade_job_toggle = settings.global["upgrade_jobs"].value
    global.repair_job_toggle = settings.global["repair_jobs"].value
    global.debug_toggle = settings.global["constructron-debug-enabled"].value
    global.job_start_delay = (settings.global["job-start-delay"].value * 60)
    global.desired_robot_count = settings.global["desired_robot_count"].value
    global.desired_robot_name = settings.global["desired_robot_name"].value
    global.construction_mat_alert = (settings.global["construction_mat_alert"].value * 60)
    global.max_jobtime = (settings.global["max-jobtime-per-job"].value * 60 * 60) --[[@as uint]]
    global.entities_per_tick = settings.global["entities_per_tick"].value --[[@as uint]]
    global.clear_robots_when_idle = settings.global["clear_robots_when_idle"].value --[[@as boolean]]
end

local init = function()
    ensure_globals()
    pathfinder.init_globals()
end

script.on_init(init)
script.on_configuration_changed(init)

--===========================================================================--
-- other
--===========================================================================--

local ev = defines.events

---@param event EventData.on_surface_created
script.on_event(ev.on_surface_created, function(event)
    local index = event.surface_index
    global.construct_queue[index] = {}
    global.deconstruct_queue[index] = {}
    global.upgrade_queue[index] = {}
    global.repair_queue[index] = {}
    global.constructrons_count[index] = 0
    global.stations_count[index] = 0
end)

---@param event EventData.on_surface_deleted
script.on_event(ev.on_surface_deleted, function(event)
    local index = event.surface_index
    global.construct_queue[index] = nil
    global.deconstruct_queue[index] = nil
    global.upgrade_queue[index] = nil
    global.repair_queue[index] = nil
    global.constructrons_count[index] = nil
    global.stations_count[index] = nil
end)

---@param event EventData.on_player_used_spider_remote
script.on_event(ev.on_player_used_spider_remote, (function(event)
    if global.spider_remote_toggle and event.vehicle.name == "constructron" then
        pathfinder.set_autopilot(event.vehicle, {})
        local request_params = {unit = event.vehicle, goal = event.position}
        pathfinder.request_path(request_params)
    end
end))

---@param event EventData.on_runtime_mod_setting_changed
script.on_event(ev.on_runtime_mod_setting_changed, function(event)
    log("mod setting change: " .. event.setting)
    local setting = event.setting
    if setting == "construct_jobs" then
        global.construction_job_toggle = settings.global["construct_jobs"].value
    elseif setting == "rebuild_jobs" then
        global.rebuild_job_toggle = settings.global["rebuild_jobs"].value
    elseif setting == "deconstruct_jobs" then
        global.deconstruction_job_toggle = settings.global["deconstruct_jobs"].value
    elseif setting == "upgrade_jobs" then
        global.upgrade_job_toggle = settings.global["upgrade_jobs"].value
    elseif setting == "repair_jobs" then
        global.repair_job_toggle = settings.global["repair_jobs"].value
    elseif setting == "constructron-debug-enabled" then
        global.debug_toggle = settings.global["constructron-debug-enabled"].value
    elseif setting == "job-start-delay" then
        global.job_start_delay = (settings.global["job-start-delay"].value * 60)
    elseif setting == "desired_robot_count" then
        global.desired_robot_count = settings.global["desired_robot_count"].value
    elseif setting == "desired_robot_name" then
        global.desired_robot_name = settings.global["desired_robot_name"].value
    elseif setting == "construction_mat_alert" then
        global.construction_mat_alert = (settings.global["construction_mat_alert"].value * 60)
    elseif setting == "max-jobtime-per-job" then
        global.max_jobtime = (settings.global["max-jobtime-per-job"].value * 60 * 60)
    elseif setting == "entities_per_tick" then
        global.entities_per_tick = settings.global["entities_per_tick"].value --[[@as uint]]
    elseif setting == "clear_robots_when_idle" then
        global.clear_robots_when_idle = settings.global["clear_robots_when_idle"].value --[[@as boolean]]
    end
end)

--===========================================================================--
-- command functions
--===========================================================================--

---@param player LuaPlayer
---@param parameters string[]
local function reset(player, parameters)
    log("control:reset")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))
    if parameters[1] == "entities" then
        game.print('Reset entities. Entity detection will now start.')
        cmd.reload_entities()
    elseif parameters[1] == "settings" then
        game.print('Reset settings to default.')
        cmd.reset_settings()
    elseif parameters[1] == "recall" then
        game.print('Recalling Constructrons to station(s).')
        cmd.recall_ctrons()
    elseif parameters[1] == "all" then
        game.print('Reset all parameters and queues complete.')
        -- Clear jobs/queues/entities
        global.job_bundles = {}
        cmd.clear_queues()
        -- Clear supporting globals
        global.stack_cache = {}
        cmd.rebuild_caches()
        -- Clear and reacquire Constructrons & Stations
        cmd.reload_entities()
        cmd.reload_ctron_status()
        cmd.reload_ctron_color()
        -- Recall Ctrons
        cmd.recall_ctrons()
        -- Clear Constructron inventory
        cmd.clear_ctron_inventory()
        -- Reacquire Deconstruction jobs
        cmd.reacquire_deconstruction_jobs()
        -- Reacquire Construction jobs
        cmd.reacquire_construction_jobs()
        -- Reacquire Upgrade jobs
        cmd.reacquire_upgrade_jobs()
    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param parameters string[]
local function clear(player, parameters)
    log("control:clear")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))
    if parameters[1] == "all" then
        game.print('All jobs, queued jobs and unprocessed entities cleared.')
        cmd.clear_queues()
        cmd.reload_ctron_status()
        cmd.reload_ctron_color()
        global.job_bundles = {}
        cmd.recall_ctrons()
    elseif parameters[1] == "queues" then
        game.print('All queued jobs and unprocessed entities cleared.')
        cmd.clear_queues()
    elseif parameters[1] == "inventory" then
        game.print('All Constructron inventories will be reset')
        cmd.clear_ctron_inventory()
    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param parameters string[]
local function enable(player, parameters)
    log("control:enable")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))
    if parameters[1] == "construction" then
        global.construction_job_toggle = true
        settings.global["construct_jobs"] = {value = true}
        cmd.reload_entities()
        cmd.reacquire_construction_jobs()
        game.print('Construction jobs enabled.')
    elseif parameters[1] == "rebuild" then
        global.rebuild_job_toggle = true
        settings.global["rebuild_jobs"] = {value = true}
        game.print('Rebuild jobs enabled.')
    elseif parameters[1] == "deconstruction" then
        global.deconstruction_job_toggle = true
        settings.global["deconstruct_jobs"] = {value = true}
        cmd.reacquire_deconstruction_jobs()
        game.print('Deconstruction jobs enabled.')
    elseif parameters[1] == "upgrade" then
        global.upgrade_job_toggle = true
        settings.global["upgrade_jobs"] = {value = true}
        cmd.reacquire_upgrade_jobs()
        game.print('Upgrade jobs enabled.')
    elseif parameters[1] == "repair" then
        global.repair_job_toggle = true
        settings.global["repair_jobs"] = {value = true}
        game.print('Repair jobs enabled.')
    elseif parameters[1] == "debug" then
        global.debug_toggle = true
        settings.global["constructron-debug-enabled"] = {value = true}
        game.print('Debug view enabled.')
    elseif parameters[1] == "landfill" then
        game.print('Landfill is now permanently enabled.')
    elseif parameters[1] == "remote" then
        global.spider_remote_toggle = true
        game.print('Spider remote enabled.')
        if game.map_settings.path_finder.use_path_cache then
            game.print('use_path_cache = true')
        else
            game.print('use_path_cache = false')
        end
    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param parameters string[]
local function disable(player, parameters)
    log("control:disable")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))
    if parameters[1] == "construction" then
        global.construction_job_toggle = false
        settings.global["construct_jobs"] = {value = false}
        game.print('Construction jobs disabled.')
    elseif parameters[1] == "rebuild" then
        global.rebuild_job_toggle = false
        settings.global["rebuild_jobs"] = {value = false}
        game.print('Rebuild jobs disabled.')
    elseif parameters[1] == "deconstruction" then
        global.deconstruction_job_toggle = false
        settings.global["deconstruct_jobs"] = {value = false}
        game.print('Deconstruction jobs disabled.')
    elseif parameters[1] == "upgrade" then
        global.upgrade_job_toggle = false
        settings.global["upgrade_jobs"] = {value = false}
        game.print('Upgrade jobs disabled.')
    elseif parameters[1] == "repair" then
        global.repair_job_toggle = false
        settings.global["repair_jobs"] = {value = false}
        game.print('Repair jobs disabled.')
    elseif parameters[1] == "debug" then
        global.debug_toggle = false
        settings.global["constructron-debug-enabled"] = {value = false}
        game.print('Debug view disabled.')
    elseif parameters[1] == "landfill" then
        game.print('Landfill is now permanently enabled.')
    elseif parameters[1] == "remote" then
        global.spider_remote_toggle = false
        game.print('Spider remote disabled.')
    else
        game.print('Command parameter does not exist.')
        cmd.help_text()
    end
end

---@param player LuaPlayer
---@param _ string[]
local function stats(player, _)
    log("control:help")
    log("by player:" .. player.name)
    local global_stats = cmd.stats()
    log(serpent.block(global_stats))
    if global_stats and player then
        for k,v in pairs(global_stats) do
            player.print(k .. ": " .. tostring(v))
        end
    end
    return global_stats
end

---@param player LuaPlayer
---@param parameters string[]
local function help(player, parameters)
    log("control:help")
    log("by player:" .. player.name)
    log("parameters: " .. serpent.block(parameters))
    cmd.help_text()
end

--===========================================================================--
-- commands
--===========================================================================--

local ctron_commands = {
    ["help"] = help,
    ["reset"] = reset,
    ["clear"] = clear,
    ["enable"] = enable,
    ["disable"] = disable,
    ["stats"] = stats
}

commands.add_command(
    "ctron",
    "/ctron reset",
    function(param)
        log("/ctron " .. (param.parameter or ""))
        if param.parameter then
            local player = game.players[param.player_index] --[[@as LuaPlayer]]
            local params = custom_lib.string_split(param.parameter, " ")
            local command = table.remove(params, 1) --[[@as string]]
            if command and ctron_commands[command] then
                ctron_commands[command](player,params)
            else
                game.print('Command parameter does not exist.')
                cmd.help_text()
            end
        end
    end
)

--===========================================================================--
--- game interfaces
--===========================================================================--

remote.add_interface("ctron_interface", ctron_commands)
