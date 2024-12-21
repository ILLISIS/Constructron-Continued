local util_func = require("script/utility_functions")
local cmd = require("script/command_functions")
local entity_proc = require("script/entity_processor")
local job_proc = require("script/job_processor")

local gui_handlers = require("script/ui")

local util = require("util")

--===========================================================================--
-- todo's!
--===========================================================================--

-- Fix visual debug text alignments and implement vertical alignment properly

--===========================================================================--
-- Main workers
--===========================================================================--

script.on_nth_tick(90, function ()
    job_proc.process_job_queue()
    gui_handlers.update_ui_windows()
end)

script.on_nth_tick(15, function()
    if not storage.entity_proc_trigger then return end -- trip switch to return early when there is nothing to process
    if next(storage.deconstruction_entities) then -- deconstruction has priority over construction.
        entity_proc.add_entities_to_chunks("deconstruction", storage.deconstruction_entities, storage.deconstruction_queue)
    elseif next(storage.construction_entities) then
        entity_proc.add_entities_to_chunks("construction", storage.construction_entities, storage.construction_queue)
    elseif next(storage.upgrade_entities) then
        entity_proc.add_entities_to_chunks("upgrade", storage.upgrade_entities, storage.upgrade_queue)
    elseif next(storage.repair_entities) then
        entity_proc.add_entities_to_chunks("repair", storage.repair_entities, storage.repair_queue)
    elseif next(storage.destroy_entities) then
        entity_proc.add_entities_to_chunks("destroy", storage.destroy_entities, storage.destroy_queue)
    else
        storage.entity_proc_trigger = false -- stop entity processing
    end
end)

-- cleanup
script.on_nth_tick(54000, (function()
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        if (storage.constructrons_count[surface_index] <= 0) or (storage.stations_count[surface_index] <= 0) then
            storage.construction_queue[surface_index] = {}
            storage.deconstruction_queue[surface_index] = {}
            storage.upgrade_queue[surface_index] = {}
            storage.repair_queue[surface_index] = {}
        end
    end
end))

--===========================================================================--
-- init
--===========================================================================--

local ensure_storages = function()
    storage.constructron_names = storage.constructron_names or { ["constructron"] = true, ["constructron-rocket-powered"] = true}
    storage.station_names = storage.station_names or { ["service_station"] = true }
    --
    storage.registered_entities = storage.registered_entities or {}
    storage.constructron_statuses = storage.constructron_statuses or {}
    --
    storage.entity_proc_trigger = storage.entity_proc_trigger or true
    --
    storage.managed_surfaces = storage.managed_surfaces or {}
    --
    storage.stack_cache = {} -- rebuild
    storage.entity_inventory_cache = {}
    --
    storage.pathfinder_requests = storage.pathfinder_requests or {}
    storage.custom_pathfinder_index = storage.custom_pathfinder_index or 0
    storage.custom_pathfinder_requests = storage.custom_pathfinder_requests or {}
    storage.mainland_chunks = storage.mainland_chunks or {}
    storage.max_pathfinder_iterations = storage.max_pathfinder_iterations or 200
    --
    storage.job_index = storage.job_index or 0
    storage.jobs = storage.jobs or {}
    --
    storage.station_requests = storage.station_requests or {}
    --
    storage.construction_index = storage.construction_index or 0
    storage.deconstruction_index = storage.deconstruction_index or 0
    storage.upgrade_index = storage.upgrade_index or 0
    storage.repair_index = storage.repair_index or 0
    storage.destroy_index = storage.destroy_index or 0
    storage.cargo_index = storage.cargo_index or 0
    --
    storage.construction_entities = storage.construction_entities or {}
    storage.deconstruction_entities = storage.deconstruction_entities or {}
    storage.upgrade_entities = storage.upgrade_entities or {}
    storage.repair_entities = storage.repair_entities or {}
    storage.destroy_entities = storage.destroy_entities or {}
    --
    storage.construction_queue = storage.construction_queue or {}
    storage.deconstruction_queue = storage.deconstruction_queue or {}
    storage.upgrade_queue = storage.upgrade_queue or {}
    storage.repair_queue = storage.repair_queue or {}
    storage.destroy_queue = storage.destroy_queue or {}
    storage.cargo_queue = storage.cargo_queue or {}
    --
    storage.constructrons = storage.constructrons or {} -- all constructron entities.
    storage.service_stations = storage.service_stations or {} -- all service stations entities.
    storage.ctron_combinators = storage.ctron_combinators or {} -- all combinator entities.
    storage.constructron_requests = storage.constructron_requests or {} -- caches logistic requests as they are nil after slot is cleared. This was needed for combinators.
    --
    storage.constructrons_count = storage.constructrons_count or {}
    storage.available_ctron_count = storage.available_ctron_count or {}
    storage.stations_count = storage.stations_count or {}
    -- settings
    storage.construction_job_toggle = storage.construction_job_toggle or {}
    storage.rebuild_job_toggle = storage.rebuild_job_toggle or {}
    storage.deconstruction_job_toggle = storage.deconstruction_job_toggle or {}
    storage.upgrade_job_toggle = storage.upgrade_job_toggle or {}
    storage.repair_job_toggle = storage.repair_job_toggle or {}
    storage.destroy_job_toggle = storage.destroy_job_toggle or {}
    -- job_types
    storage.job_types = {
        "deconstruction",
        "construction",
        "upgrade",
        "repair",
        "destroy",
        "cargo"
    }
    -- ui
    storage.user_interface = storage.user_interface or {}
    for _, player in pairs(game.players) do
        storage.user_interface[player.index] = storage.user_interface[player.index] or {
            surface = player.surface,
            main_ui = {
                elements = {}
            },
            settings_ui = {
                elements = {}
            },
            job_ui = {
                elements = {}
            },
            cargo_ui = {
                elements = {}
            },
            logistics_ui = {
                elements = {}
            },
        }
    end
    -- ammunition setup
    local init_ammo_name
    if storage.ammo_name == nil or not prototypes.item[storage.ammo_name[1]] then
        storage.ammo_name = {}
        if prototypes.item["rocket"] then
            init_ammo_name = { name = "rocket", quality = "normal" }
        else
            -- get ammo prototypes
            local ammo_prototypes = prototypes.get_item_filtered{{filter = "type", type = "ammo"}} -- TODO: check if can be filtered further in future API versions.
            -- iterate through ammo prototypes to find rocket ammo
            for _, ammo in pairs(ammo_prototypes) do
                if ammo.ammo_category.name == "rocket" then -- check if this is rocket type ammo
                    init_ammo_name = { name = ammo.name, quality = "normal" } -- set the variable to be used in the surface loop
                    break
                end
            end
        end
    end
    storage.ammo_count = storage.ammo_count or {}
    storage.desired_robot_count = storage.desired_robot_count or {}
    -- robot name
    local init_robot_name
    if storage.desired_robot_name == nil or not prototypes.item[storage.desired_robot_name[1]] then
        storage.desired_robot_name = {}
        if prototypes.item["construction-robot"] then
            init_robot_name = { name = "construction-robot", quality = "normal" }
        else
            local valid_robots = prototypes.get_entity_filtered{{filter = "type", type = "construction-robot"}}
            local valid_robot_name = util_func.firstoflct(valid_robots)
            init_robot_name = { name = valid_robot_name, quality = "normal" }
        end
    end
    -- repair tool
    local init_repair_tool_name
    if storage.repair_tool_name == nil or not prototypes.item[storage.repair_tool_name[1]] then
        storage.repair_tool_name = {}
        if prototypes.item["repair-pack"] then
            init_repair_tool_name = { name = "repair-pack", quality = "normal" }
        else
            local valid_repair_tools = prototypes.get_item_filtered{{filter = "name", name = "repair-pack"}} -- TODO: check if can be filtered further in future API versions.
            local valid_repair_tool_name = util_func.firstoflct(valid_repair_tools)
            init_repair_tool_name = { name = valid_repair_tool_name, quality = "normal" }
        end
    end
    -- non surface specific settings
    storage.job_start_delay = storage.job_start_delay or 300 -- five seconds
    storage.entities_per_second = storage.entities_per_second or 1000
    storage.debug_toggle = storage.debug_toggle or false
    storage.horde_mode = storage.horde_mode or false
    -- set per surface setting values
    for _, surface in pairs(game.surfaces) do
        -- per surface settings
        local surface_index = surface.index
        storage.construction_job_toggle[surface_index] = storage.construction_job_toggle[surface_index] or true
        storage.rebuild_job_toggle[surface_index] = storage.rebuild_job_toggle[surface_index] or true
        storage.deconstruction_job_toggle[surface_index] = storage.deconstruction_job_toggle[surface_index] or true
        storage.upgrade_job_toggle[surface_index] = storage.upgrade_job_toggle[surface_index] or true
        storage.repair_job_toggle[surface_index] = storage.repair_job_toggle[surface_index] or true
        storage.destroy_job_toggle[surface_index] = storage.destroy_job_toggle[surface_index] or false
        storage.ammo_name[surface_index] = storage.ammo_name[surface_index] or init_ammo_name
        storage.ammo_count[surface_index] = storage.ammo_count[surface_index] or 0
        storage.desired_robot_count[surface_index] = storage.desired_robot_count[surface_index] or 50
        storage.desired_robot_name[surface_index] = storage.desired_robot_name[surface_index] or init_robot_name
        storage.repair_tool_name[surface_index] = storage.repair_tool_name[surface_index] or init_repair_tool_name
        -- per surface variables
        storage.constructrons_count[surface_index] = storage.constructrons_count[surface_index] or 0
        storage.available_ctron_count[surface_index] = storage.available_ctron_count[surface_index] or storage.constructrons_count[surface_index]
        storage.stations_count[surface_index] = storage.stations_count[surface_index] or 0
        storage.construction_queue[surface_index] = storage.construction_queue[surface_index] or {}
        storage.deconstruction_queue[surface_index] = storage.deconstruction_queue[surface_index] or {}
        storage.upgrade_queue[surface_index] = storage.upgrade_queue[surface_index] or {}
        storage.repair_queue[surface_index] = storage.repair_queue[surface_index] or {}
        storage.destroy_queue[surface_index] = storage.destroy_queue[surface_index] or {}
        storage.cargo_queue[surface_index] = storage.cargo_queue[surface_index] or {}
    end
    -- build allowed items cache (this is used to filter out entities that do not have recipes)
    storage.allowed_items = {}
    for item_name, _ in pairs(prototypes.item) do
        local recipes = prototypes.get_recipe_filtered({
                {filter = "has-product-item", elem_filters = {{filter = "name", name = item_name}}},
            })
        for _ , recipe in pairs(recipes) do
            if not game.forces["player"].recipes[recipe.name].hidden then -- if the recipe is hidden disallow it
                storage.allowed_items[item_name] = true
            end
        end
        if storage.allowed_items[item_name] == nil then -- some items do not have recipes so set the item to disallowed
            storage.allowed_items[item_name] = false
        end
    end
    local autoplace_entities = prototypes.get_entity_filtered{{filter="autoplace"}}
    for entity_name, entity in pairs(autoplace_entities) do
        if entity.mineable_properties and entity.mineable_properties.products then
            storage.allowed_items[entity_name] = true
        end
    end
    -- allowed_items overrides as item/entities do not match what is mined (this is particularly for cargo jobs)
    storage.allowed_items["raw-fish"] = true
    storage.allowed_items["wood"] = true
    -- build required_items cache (used in add_entities_to_chunks)
    storage.items_to_place_cache = {}
    for name, v in pairs(prototypes.entity) do
        if v.items_to_place_this ~= nil and v.items_to_place_this[1] and v.items_to_place_this[1].name then -- bots will only ever use the first item from this list
            storage.items_to_place_cache[name] = {item = v.items_to_place_this[1].name, count = v.items_to_place_this[1].count}
        end
    end
    for name, v in pairs(prototypes.tile) do
        if v.items_to_place_this ~= nil and v.items_to_place_this[1] and v.items_to_place_this[1].name then -- bots will only ever use the first item from this list
            storage.items_to_place_cache[name] = {item = v.items_to_place_this[1].name, count = v.items_to_place_this[1].count}
        end
    end
    -- build trash_items_cache
    storage.trash_items_cache = {}
    for entity_name, prototype in pairs(prototypes.entity) do
        if prototype.mineable_properties and prototype.mineable_properties.products then
            for _, product in pairs(prototype.mineable_properties.products) do
                if product.type == "item" then
                    storage.trash_items_cache[entity_name] = storage.trash_items_cache[entity_name] or {}
                    storage.trash_items_cache[entity_name][product.name] = product.amount_max or product.amount
                end
            end
        else
            storage.trash_items_cache[entity_name] = {}
        end
    end
    -- build water tile cache
    storage.water_tile_cache = {}
    local water_tile_prototypes = prototypes.get_tile_filtered{{filter="collision-mask",mask={layers ={["water_tile"]=true}},mask_mode="contains-any"}}
    for tile_name, _ in pairs(water_tile_prototypes) do
        storage.water_tile_cache[tile_name] = true
    end
end

local init = function()
    ensure_storages()
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
    if name == "ctron-get-selection-tool" then
        local player = game.get_player(event.player_index)
        if not player then return end
        local cursor_stack = player.cursor_stack
        if not cursor_stack then return end
        if not cursor_stack.valid_for_read or cursor_stack.name ~= "ctron-selection-tool" then
            if not player.clear_cursor() then return end
            cursor_stack.set_stack({ name = "ctron-selection-tool", count = 1 })
        elseif cursor_stack.name == "ctron-selection-tool" and not player.gui.screen.ctron_main_frame then
            player.clear_cursor()
            gui_handlers.open_main_window(player)
        end
    elseif name == "ctron-open-ui" then
        local player = game.get_player(event.player_index)
        if not player then return end
        gui_handlers.open_main_window(player)
    end
end)

script.on_event("ctron-get-selection-tool", function (event)
    local name = event.input_name
    if name ~= "ctron-get-selection-tool" then return end
    local player = game.get_player(event.player_index)
    if not player then return end
    local cursor_stack = player.cursor_stack
    if not cursor_stack then return end
    if not cursor_stack.valid_for_read or cursor_stack.name ~= "ctron-selection-tool" then
        if not player.clear_cursor() then return end
        cursor_stack.set_stack({ name = "ctron-selection-tool", count = 1 })
    elseif cursor_stack.name == "ctron-selection-tool" and not player.gui.screen.ctron_main_frame then
        player.clear_cursor()
        gui_handlers.open_main_window(player)
    end
end)

script.on_event(ev.on_surface_created, function(event)
    local surface_index = event.surface_index
    storage.construction_queue[surface_index] = {}
    storage.deconstruction_queue[surface_index] = {}
    storage.upgrade_queue[surface_index] = {}
    storage.repair_queue[surface_index] = {}
    storage.destroy_queue[surface_index] = {}
    storage.cargo_queue[surface_index] = {}
    storage.constructrons_count[surface_index] = 0
    storage.available_ctron_count[surface_index] = 0
    storage.stations_count[surface_index] = 0

    -- per surface settings
    storage.construction_job_toggle[surface_index] = true
    storage.rebuild_job_toggle[surface_index] = true
    storage.deconstruction_job_toggle[surface_index] = true
    storage.upgrade_job_toggle[surface_index] = true
    storage.repair_job_toggle[surface_index] = true
    storage.destroy_job_toggle[surface_index] = false
    storage.ammo_name[surface_index] = storage.ammo_name[1]
    storage.ammo_count[surface_index] = 0
    storage.desired_robot_count[surface_index] = 50
    storage.desired_robot_name[surface_index] = storage.desired_robot_name[1]
    storage.repair_tool_name[surface_index] = storage.repair_tool_name[1]
end)

script.on_event(ev.on_surface_deleted, function(event)
    local surface_index = event.surface_index
    storage.construction_queue[surface_index] = nil
    storage.deconstruction_queue[surface_index] = nil
    storage.upgrade_queue[surface_index] = nil
    storage.repair_queue[surface_index] = nil
    storage.destroy_queue[surface_index] = nil
    storage.cargo_queue[surface_index] = nil
    storage.constructrons_count[surface_index] = nil
    storage.available_ctron_count[surface_index] = nil
    storage.stations_count[surface_index] = nil

    -- per surface settings
    storage.construction_job_toggle[surface_index] = nil
    storage.rebuild_job_toggle[surface_index] = nil
    storage.deconstruction_job_toggle[surface_index] = nil
    storage.upgrade_job_toggle[surface_index] = nil
    storage.repair_job_toggle[surface_index] = nil
    storage.destroy_job_toggle[surface_index] = nil
    storage.ammo_name[surface_index] = nil
    storage.ammo_count[surface_index] = nil
    storage.desired_robot_count[surface_index] = nil
    storage.desired_robot_name[surface_index] = nil
    storage.repair_tool_name[surface_index] = nil
    storage.ctron_combinators[surface_index] = nil
end)

script.on_nth_tick(10, function()
    for _, pathfinder in pairs(storage.custom_pathfinder_requests) do
        pathfinder:findpath()
    end
end)

gui_handlers.register()

--===========================================================================--
--- game interfaces
--===========================================================================--

--------------------------------------------------------------------------------
--- before using the below functions please notify the maintainer of this mod
---------------------------------------------------------------------------------
--- used by:
--- Planet Maraxis
--- Spidertron Patrols
--- Construction Planner

-- remote interface to inform this mod of a new constructron type (this mod will handle the entity for you)
---@param name string
local function remote_add_ctron_name(name)
    storage.constructron_names[name] = true
end

-- remote interface to inform this mod of a new station type (this mod will handle the entity for you)
---@param name string
local function remote_add_station_name(name)
    storage.station_names[name] = true
end

-- remote interface to get constructron names
local function remote_get_ctron_names()
    return storage.constructron_names
end

-- remote interface to get station names
local function remote_get_station_names()
    return storage.station_names
end

-- notify this mod of alignments new entity to be built (if this not naturally handled by the on_event scripting)
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

-- notify this mod of new entities to be built (if this not naturally handled by the on_event scripting)
---@param entities LuaEntity[]
local function remote_entities_built(entities)
    for _, entity in pairs(entities) do
        remote_entity_built(entity)
    end
end

remote.add_interface("ctron", {
    ["scan-entity"] = remote_entity_built,
    ["scan-entities"] = remote_entities_built,
    ["add-ctron-names"] = remote_add_ctron_name,
    ["get-ctron-names"] = remote_get_ctron_names,
    ["add-station-names"] = remote_add_station_name,
    ["get-station-names"] = remote_get_station_names,
})
