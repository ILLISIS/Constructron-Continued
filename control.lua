local custom_lib = require("script/custom_lib")
local debug_lib = require("script/debug_lib")
local cmd = require("script/command_functions")
local entity_proc = require("script/entity_processor")
local job_proc = require("script/job_processor")

--===========================================================================--
-- Main workers
--===========================================================================--

script.on_nth_tick(90, job_proc.process_job_queue)

script.on_nth_tick(15, function()
    if not global.entity_proc_trigger then return end -- trip switch to return early when there is nothing to process
    if next(global.deconstruction_entities) then -- deconstruction has priority over construction.
        entity_proc.add_entities_to_chunks("deconstruction", global.deconstruction_entities, global.deconstruction_queue, global.deconstruction_tick)
    elseif next(global.construction_entities) then
        entity_proc.add_entities_to_chunks("construction", global.construction_entities, global.construction_queue, global.construction_tick)
    elseif next(global.upgrade_entities) then
        entity_proc.add_entities_to_chunks("upgrade", global.upgrade_entities, global.upgrade_queue, global.upgrade_tick)
    elseif next(global.repair_entities) then
        entity_proc.add_entities_to_chunks("repair", global.repair_entities, global.repair_queue, global.repair_tick)
    elseif next(global.destroy_entities) then
        entity_proc.add_entities_to_chunks("destroy", global.destroy_entities, global.destroy_queue, global.destroy_tick)
    else
        global.entity_proc_trigger = false -- stop entity processing
        global.queue_proc_trigger = true -- start queue processing
    end
end)

-- cleanup
script.on_nth_tick(54000, (function()
    debug_lib.DebugLog('Surface job validation & cleanup')
    for _, surface in pairs(game.surfaces) do
        if (global.constructrons_count[surface.index] <= 0) or (global.stations_count[surface.index] <= 0) then
            global.construction_queue[surface.index] = {}
            global.deconstruction_queue[surface.index] = {}
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
    global.entity_proc_trigger = global.entity_proc_triggerr or true
    global.queue_proc_trigger = global.queue_proc_trigger or true
    global.job_proc_trigger = global.job_proc_trigger or true
    --
    global.managed_surfaces = global.managed_surfaces or {}
    --
    global.stack_cache = {} -- rebuild
    global.entity_inventory_cache = {}
    --
    global.pathfinder_requests = global.pathfinder_requests or {}
    global.custom_pathfinder_index = global.custom_pathfinder_index or 0
    global.custom_pathfinder_requests = global.custom_pathfinder_requests or {}
    global.mainland_chunks = global.mainland_chunks or {}
    --
    global.job_index = global.job_index or 0
    global.jobs = global.jobs or {}
    --
    global.construction_index = global.construction_index or 0
    global.deconstruction_index = global.deconstruction_index or 0
    global.upgrade_index = global.upgrade_index or 0
    global.repair_index = global.repair_index or 0
    global.destroy_index = global.destroy_index or 0
    --
    global.construction_entities = global.construction_entities or {}
    global.deconstruction_entities = global.deconstruction_entities or {}
    global.upgrade_entities = global.upgrade_entities or {}
    global.repair_entities = global.repair_entities or {}
    global.destroy_entities = global.destroy_entities or {}
    --
    global.construction_queue = global.construction_queue or {}
    global.deconstruction_queue = global.deconstruction_queue or {}
    global.upgrade_queue = global.upgrade_queue or {}
    global.repair_queue = global.repair_queue or {}
    global.destroy_queue = global.destroy_queue or {}
    --
    global.constructrons = global.constructrons or {} -- all constructron entities.
    global.service_stations = global.service_stations or {} -- all service stations entities.
    global.station_combinators = global.station_combinators or {} -- all combinator entities.
    global.constructron_requests = global.constructron_requests or {} -- caches logistic requests as they are nil after slot is cleared. This was needed for combinators.
    --
    global.constructrons_count = global.constructrons_count or {}
    global.available_ctron_count = global.available_ctron_count or {}
    global.stations_count = global.stations_count or {}
    --
    for _, surface in pairs(game.surfaces) do
        global.constructrons_count[surface.index] = global.constructrons_count[surface.index] or 0
        global.available_ctron_count[surface.index] = global.available_ctron_count[surface.index] or global.constructrons_count[surface.index]
        global.stations_count[surface.index] = global.stations_count[surface.index] or 0
        global.construction_queue[surface.index] = global.construction_queue[surface.index] or {}
        global.deconstruction_queue[surface.index] = global.deconstruction_queue[surface.index] or {}
        global.upgrade_queue[surface.index] = global.upgrade_queue[surface.index] or {}
        global.repair_queue[surface.index] = global.repair_queue[surface.index] or {}
        global.destroy_queue[surface.index] = global.destroy_queue[surface.index] or {}
    end
    -- build allowed items cache (this is used to filter out entities that do not have recipes)
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
    local autoplace_entities = game.get_filtered_entity_prototypes{{filter="autoplace"}}
    for entity_name, entity in pairs(autoplace_entities) do
        if entity.mineable_properties and entity.mineable_properties.products then
            global.allowed_items[entity_name] = true
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
    -- build trash_items_cache
    global.trash_items_cache = {}
    for entity_name, prototype in pairs(game.entity_prototypes) do
        if prototype.mineable_properties and prototype.mineable_properties.products then
            for _, product in pairs(prototype.mineable_properties.products) do
                if product.type == "item" then
                    global.trash_items_cache[entity_name] = global.trash_items_cache[entity_name] or {}
                    global.trash_items_cache[entity_name][product.name] = product.amount_max or product.amount
                end
            end
        else
            global.trash_items_cache[entity_name] = {}
        end
    end
    -- build water tile cache
    global.water_tile_cache = {}
    local water_tile_prototypes = game.get_filtered_tile_prototypes{{filter="collision-mask",mask={["water-tile"]=true},mask_mode="contains-any"}}
    for tile_name, _ in pairs(water_tile_prototypes) do
        global.water_tile_cache[tile_name] = true
    end
    -- settings
    global.construction_job_toggle = settings.global["construct_jobs"].value
    global.rebuild_job_toggle = settings.global["rebuild_jobs"].value
    global.deconstruction_job_toggle = settings.global["deconstruct_jobs"].value
    global.upgrade_job_toggle = settings.global["upgrade_jobs"].value
    global.repair_job_toggle = settings.global["repair_jobs"].value
    global.destroy_job_toggle = settings.global["destroy_jobs"].value
    global.ammo_name = settings.global["ammo_name"].value
    global.ammo_count = settings.global["ammo_count"].value
    global.debug_toggle = settings.global["constructron-debug-enabled"].value
    global.job_start_delay = (settings.global["job-start-delay"].value * 60)
    global.desired_robot_count = settings.global["desired_robot_count"].value
    global.desired_robot_name = settings.global["desired_robot_name"].value
    global.entities_per_second = settings.global["entities_per_second"].value --[[@as uint]]
    global.horde_mode = settings.global["horde_mode"].value
end

local init = function()
    ensure_globals()
    game.map_settings.path_finder.use_path_cache = false
    -- use_path_cache Klonan's explanation:
    -- So, when path cache is enabled, negative path cache is also enabled.
    -- The problem is, when a single unit inside a nest can't get to the silo,
    -- He tells all other biters nearby that they also can't get to the silo.
    -- Which causes whole groups of them just to chillout and idle...
    -- This applies to all paths as the pathfinder is generic
end

script.on_init(init)
script.on_configuration_changed(init)

--===========================================================================--
-- other
--===========================================================================--

local ev = defines.events

script.on_event(ev.on_lua_shortcut, function (event)
    local name = event.prototype_name
    if name ~= "ctron-get-selection-tool" then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local cursor_stack = player.cursor_stack
    if not cursor_stack then return end
    if player.clear_cursor() then
        cursor_stack.set_stack({ name = "ctron-selection-tool", count = 1 })
    end
end)

script.on_event("ctron-get-selection-tool", function (event)
    local name = event.input_name or event.prototype_name
    if name ~= "ctron-get-selection-tool" then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local cursor_stack = player.cursor_stack
    if not cursor_stack then return end
    cursor_stack.set_stack({ name = "ctron-selection-tool", count = 1 })
end)

script.on_event(ev.on_surface_created, function(event)
    local index = event.surface_index
    global.construction_queue[index] = {}
    global.deconstruction_queue[index] = {}
    global.upgrade_queue[index] = {}
    global.repair_queue[index] = {}
    global.constructrons_count[index] = 0
    global.stations_count[index] = 0
end)

script.on_event(ev.on_surface_deleted, function(event)
    local index = event.surface_index
    global.construction_queue[index] = nil
    global.deconstruction_queue[index] = nil
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

script.on_nth_tick(10, function()
    for _, pathfinder in pairs(global.custom_pathfinder_requests) do
        pathfinder:findpath()
    end
end)

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
    elseif setting == "destroy_jobs" then
        global.destroy_job_toggle = settings.global["destroy_jobs"].value
    elseif setting == "constructron-debug-enabled" then
        global.debug_toggle = settings.global["constructron-debug-enabled"].value
    elseif setting == "job-start-delay" then
        global.job_start_delay = (settings.global["job-start-delay"].value * 60)
    elseif setting == "desired_robot_count" then
        global.desired_robot_count = settings.global["desired_robot_count"].value
    elseif setting == "desired_robot_name" then
        -- validate robot name
        if not game.item_prototypes[settings.global["desired_robot_name"].value] then
            if game.item_prototypes["construction-robot"] then
                settings.global["desired_robot_name"] = {value = "construction-robot"}
                global.desired_robot_name = "construction-robot"
                game.print("Constructron-Continued: **WARNING** desired_robot_name is not a valid name in mod settings! Robot name reset!")
            else
                local valid_robots = game.get_filtered_entity_prototypes{{filter = "type", type = "construction-robot"}}
                local valid_robot_name = pairs(valid_robots)(nil,nil)
                settings.global["desired_robot_name"] = {value = valid_robot_name}
                game.print("Constructron-Continued: **WARNING** desired_robot_name is not a valid name in mod settings! Robot name reset!")
            end
        else
            global.desired_robot_name = settings.global["desired_robot_name"].value
        end
    elseif setting == "ammo_name" then
        -- validate ammo name
        if not game.item_prototypes[settings.global["ammo_name"].value] then
            if game.item_prototypes["rocket"] then
                settings.global["ammo_name"] = {value = "rocket"}
                global.desired_robot_name = "rocket"
                game.print("Constructron-Continued: **WARNING** ammo_name is not a valid name in mod settings! Ammo name reset!")
            else
                game.print("Constructron-Continued: **WARNING** ammo_name is not a valid name in mod settings! Ammo requests disabled!")
                settings.global["ammo_count"] = {value = 0}
                global.ammo_count = 0
            end
        else
            global.ammo_name = settings.global["ammo_name"].value
        end
    elseif setting == "ammo_count" then
        global.ammo_count = settings.global["ammo_count"].value
    elseif setting == "entities_per_second" then
        global.entities_per_second = settings.global["entities_per_second"].value --[[@as uint]]
    elseif setting == "horde_mode" then
        global.horde_mode = settings.global["horde_mode"].value
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
        global.custom_pathfinder_index =  0
        global.custom_pathfinder_requests = {}
        global.pathfinder_requests = {}
        game.print('Reset all parameters and queues complete.')
        -- Clear jobs/queues/entities
        global.jobs = {}
        global.job_index = 0
        cmd.clear_queues()
        -- Clear supporting globals
        global.stack_cache = {}
        global.entity_inventory_cache = {}
        cmd.rebuild_caches()
        -- Clear and reacquire Constructrons & Stations
        cmd.reload_entities()
        cmd.reset_available_ctron_count()
        cmd.reload_ctron_status()
        cmd.reload_ctron_color()
        -- Recall Ctrons
        cmd.recall_ctrons()
        -- Reset combinators
        cmd.reset_combinator_signals()
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
        global.pathfinder_requests = {}
        game.print('All jobs, queued jobs and unprocessed entities cleared.')
        cmd.clear_queues()
        cmd.reload_ctron_status()
        cmd.reload_ctron_color()
        global.jobs = {}
        global.job_index = 0
        cmd.recall_ctrons()
        cmd.reload_entities() -- needed to reset roboport construction radius
    elseif parameters[1] == "queues" then
        game.print('All queued jobs and unprocessed entities cleared.')
        cmd.clear_queues()
    elseif parameters[1] == "inventory" then
        game.print('All Constructron inventories will be reset')
        cmd.clear_ctron_inventory()
    elseif parameters[1] == "construction" then
        cmd.clear_single_job_type("construction")
        game.print('All queued ' .. parameters[1] .. ' jobs and unprocessed entities cleared.')
    elseif parameters[1] == "deconstruction" then
        cmd.clear_single_job_type("deconstruction")
        game.print('All queued ' .. parameters[1] .. ' jobs and unprocessed entities cleared.')
    elseif parameters[1] == "upgrade" then
        cmd.clear_single_job_type("upgrade")
        game.print('All queued ' .. parameters[1] .. ' jobs and unprocessed entities cleared.')
    elseif parameters[1] == "repair" then
        cmd.clear_single_job_type("repair")
        game.print('All queued ' .. parameters[1] .. ' jobs and unprocessed entities cleared.')
    elseif parameters[1] == "destroy" then
        cmd.clear_single_job_type("destroy")
        game.print('All queued ' .. parameters[1] .. ' jobs and unprocessed entities cleared.')
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
    elseif parameters[1] == "destroy" then
        global.destroy_job_toggle = true
        settings.global["destroy_jobs"] = {value = true}
        game.print('Destroy jobs enabled.')
    elseif parameters[1] == "horde" then
        global.horde_mode = true
        settings.global["horde_mode"] = {value = true}
        game.print('Horde Mode enabled.')
    elseif parameters[1] == "all" then
        global.construction_job_toggle = true
        settings.global["construct_jobs"] = {value = true}
        cmd.reload_entities()
        cmd.reacquire_construction_jobs()
        game.print('Construction jobs enabled.')
        global.rebuild_job_toggle = true
        settings.global["rebuild_jobs"] = {value = true}
        game.print('Rebuild jobs enabled.')
        global.deconstruction_job_toggle = true
        settings.global["deconstruct_jobs"] = {value = true}
        cmd.reacquire_deconstruction_jobs()
        game.print('Deconstruction jobs enabled.')
        global.upgrade_job_toggle = true
        settings.global["upgrade_jobs"] = {value = true}
        cmd.reacquire_upgrade_jobs()
        game.print('Upgrade jobs enabled.')
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
    elseif parameters[1] == "destroy" then
        global.destroy_job_toggle = false
        settings.global["destroy_jobs"] = {value = false}
        game.print('Destroy jobs disabled.')
    elseif parameters[1] == "horde" then
        global.horde_mode = false
        settings.global["horde_mode"] = {value = false}
        game.print('Horde Mode disabled.')
    elseif parameters[1] == "all" then
        global.construction_job_toggle = false
        settings.global["construct_jobs"] = {value = false}
        game.print('Construction jobs disabled.')
        global.rebuild_job_toggle = false
        settings.global["rebuild_jobs"] = {value = false}
        game.print('Rebuild jobs disabled.')
        global.deconstruction_job_toggle = false
        settings.global["deconstruct_jobs"] = {value = false}
        game.print('Deconstruction jobs disabled.')
        global.upgrade_job_toggle = false
        settings.global["upgrade_jobs"] = {value = false}
        game.print('Upgrade jobs disabled.')
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
        for k, v in pairs(global_stats) do
            player.print(k .. ": " .. tostring(v))
        end
    end
    local available_count = 0
    local used_count = 0
    for _, constructron in pairs(global.constructron_statuses) do
        if (constructron.busy == true) then
            used_count = used_count + 1
        else
            available_count = available_count + 1
        end
    end
    game.print('Constructrons on a job: ' .. used_count ..'')
    game.print('Idle Constructrons: ' .. available_count .. '')
    game.print('entity_proc_trigger is ' .. tostring(global.entity_proc_trigger) .. '')
    game.print('queue_proc_trigger is ' .. tostring(global.queue_proc_trigger) .. '')
    game.print('job_proc_trigger is ' .. tostring(global.job_proc_trigger) .. '')
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
    "help",
    function(param)
        log("/ctron " .. (param.parameter or ""))
        if param.parameter then
            local player = {name="server"}
            if param.player_index ~= nil then
                player = game.players[param.player_index] --[[@as LuaPlayer]]
            end
            local params = custom_lib.string_split(param.parameter, " ")
            local command = table.remove(params, 1) --[[@as string]]
            if command and ctron_commands[command] then
                ctron_commands[command](player, params)
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

---@param entity LuaEntity
local function remote_entity_built(entity)
    ---@type EventData.script_raised_built
    local event = {
        tick = game.tick,
        name = defines.events.script_raised_built,
        entity = entity,
    }
    entity_proc.on_built_entity(event)
end

---@param entities LuaEntity[]
local function remote_entities_built(entities)
    for _, entity in pairs(entities) do
        remote_entity_built(entity)
    end
end

remote.add_interface("ctron", {
    ["scan-entity"] = remote_entity_built,
    ["scan-entities"] = remote_entities_built
})
