local ctron = require("script/constructron")
local pathfinder = require("script/pathfinder")

local me = {}

me.reset_settings = function()
    settings.global["construct_jobs"] = {value = true}
    settings.global["rebuild_jobs"] = {value = true}
    settings.global["deconstruct_jobs"] = {value = true}
    settings.global["upgrade_jobs"] = {value = true}
    settings.global["repair_jobs"] = {value = false}
    settings.global["constructron-debug-enabled"] = {value = false}
    settings.global["desired_robot_count"] = {value = 50}
    settings.global["desired_robot_name"] = {value = "construction-robot"}
    settings.global["entities_per_tick"] = {value = 1000}
    settings.global["clear_robots_when_idle"] = {value = false}
    settings.global["job-start-delay"] = {value = 5}
    settings.global["horde_mode"] = {value = false}
end

me.clear_queues = function()
    global.ghost_entities = {}
    global.deconstruction_entities = {}
    global.upgrade_entities = {}
    global.repair_entities = {}

    global.ghost_index = 0
    global.decon_index = 0
    global.updgrade_index = 0
    global.repair_index = 0

    global.construct_queue = {}
    global.deconstruct_queue = {}
    global.upgrade_queue = {}
    global.repair_queue = {}

    for s, surface in pairs(game.surfaces) do
        global.construct_queue[surface.index] = global.construct_queue[surface.index] or {}
        global.deconstruct_queue[surface.index] = global.deconstruct_queue[surface.index] or {}
        global.upgrade_queue[surface.index] = global.upgrade_queue[surface.index] or {}
        global.repair_queue[surface.index] = global.repair_queue[surface.index] or {}
    end
end

me.reacquire_construction_jobs = function()
    for _, surface in pairs(game.surfaces) do
        local ghosts = surface.find_entities_filtered {
            name = {"entity-ghost", "tile-ghost", "item-request-proxy"},
            force = {"player", "neutral"},
            surface = surface.name
        }
        game.print('found '.. #ghosts ..' entities on '.. surface.name ..' to construct.')
        for _, entity in ipairs(ghosts) do
            global.ghost_index = global.ghost_index + 1
            global.ghost_entities[global.ghost_index] = entity
        end
        global.ghost_tick = game.tick
        global.entity_proc_trigger = true
    end
end

me.reacquire_deconstruction_jobs = function()
    for _, surface in pairs(game.surfaces) do
        local decons = surface.find_entities_filtered {
            to_be_deconstructed = true,
            force = {"player", "neutral"},
            surface = surface.name
        }
        game.print('found '.. #decons ..' entities on '.. surface.name ..' to deconstruct.')
        for _, entity in ipairs(decons) do
            global.decon_index = global.decon_index + 1
            global.deconstruction_entities[global.decon_index] = entity
        end
        global.deconstruct_marked_tick = game.tick
        global.entity_proc_trigger = true
    end
end

me.reacquire_upgrade_jobs = function()
    for _, surface in pairs(game.surfaces) do
        local upgrades = surface.find_entities_filtered {
            to_be_upgraded = true,
            force = "player",
            surface = surface.name
        }
        game.print('found '.. #upgrades ..' entities on '.. surface.name ..' to upgrade.')
        for _, entity in ipairs(upgrades) do
            global.upgrade_index = global.upgrade_index + 1
            global.upgrade_entities[global.upgrade_index] = entity
        end
        global.upgrade_marked_tick = game.tick
        global.entity_proc_trigger = true
    end
end

me.reload_entities = function()
    global.registered_entities = {}

    global.service_stations = {}
    global.constructrons = {}

    global.stations_count = {}
    global.constructrons_count = {}

    me.reacquire_stations()
    me.reacquire_ctrons()
end

me.reacquire_stations = function()
    for s, surface in pairs(game.surfaces) do
        global.stations_count[surface.index] = 0
        local stations = surface.find_entities_filtered {
            name = "service_station",
            force = "player",
            surface = surface.name
        }

        for k, station in pairs(stations) do
            local unit_number = station.unit_number
            if not global.service_stations[unit_number] then
                global.service_stations[unit_number] = station
            end

            local registration_number = script.register_on_entity_destroyed(station)
            global.registered_entities[registration_number] = {
                name = "service_station",
                surface = surface.index
            }

            global.stations_count[surface.index] = global.stations_count[surface.index] + 1
        end
        game.print('Registered ' .. global.stations_count[surface.index] .. ' stations on ' .. surface.name .. '.')
    end
end

me.reacquire_ctrons = function()
    for s, surface in pairs(game.surfaces) do
        global.constructrons_count[surface.index] = 0
        local constructrons = surface.find_entities_filtered {
            name = {"constructron", "constructron-rocket-powered"},
            force = "player",
            surface = surface.name
        }

        for k, constructron in pairs(constructrons) do
            local unit_number = constructron.unit_number
            if not global.constructrons[unit_number] then
                global.constructrons[unit_number] = constructron
            end

            local registration_number = script.register_on_entity_destroyed(constructron)
            global.registered_entities[registration_number] = {
                name = "constructron",
                surface = surface.index
            }

            -- Reset Hardcodes
            ctron.enable_roboports(constructron.grid)
            constructron.grid.inhibit_movement_bonus = false

            global.constructrons_count[surface.index] = global.constructrons_count[surface.index] + 1
        end
        game.print('Registered ' .. global.constructrons_count[surface.index] .. ' constructrons on ' .. surface.name .. '.')
    end
end

me.reload_ctron_status = function()
    for k, constructron in pairs(global.constructrons) do
        ctron.set_constructron_status(constructron, 'busy', false)
    end
end

me.reload_ctron_color = function()
    for k, constructron in pairs(global.constructrons) do
        ctron.paint_constructron(constructron, 'idle')
    end
end

me.recall_ctrons = function()
    for _, surface in pairs(game.surfaces) do
        if (global.stations_count[surface.index] > 0) and (global.constructrons_count[surface.index] > 0) then
            local constructrons = surface.find_entities_filtered {
                name = {"constructron", "constructron-rocket-powered"},
                force = "player",
                surface = surface.name
            }
            for _, constructron in pairs(constructrons) do
                local closest_station = ctron.get_closest_service_station(constructron)
                pathfinder.init_path_request(constructron, closest_station.position) -- find path to station
            end
        else
            game.print('No stations to recall Constructrons to on ' .. surface.name .. '.')
        end
    end
end

me.clear_ctron_inventory = function()
    local slot = 1

    for c, constructron in pairs(global.constructrons) do
        local inventory = constructron.get_inventory(defines.inventory.spider_trunk)
        local filtered_items = {}

        for i = 1, #inventory do
            local item = inventory[i]

            if item.valid_for_read then
                if not filtered_items[item.name] then
                    constructron.set_vehicle_logistic_slot(slot, {
                        name = item.name,
                        min = 0,
                        max = 0
                    })
                    slot = slot + 1
                    filtered_items[item.name] = true
                end
            end
        end
    end
end

me.rebuild_caches = function()
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
        end
    end
end

me.stats = function()
    local queues = {
        "registered_entities",
        "constructron_statuses",
        "ghost_entities",
        "deconstruction_entities",
        "upgrade_entities",
        "repair_entities",
        "job_bundles",
        "constructrons",
        "service_stations",
    }
    local global_stats = {
    }
    for _, data_name in pairs(queues) do
        local data = global[data_name]
        if type(data)=="table" then
            global_stats[data_name] = table_size(data)
        else
            global_stats[data_name] = tostring(data)
        end
    end
    local surface_queues = {
        "constructrons_count",
        "stations_count",
        "construct_queue",
        "deconstruct_queue",
        "upgrade_queue",
        "repair_queue",
    }
    for s, surface in pairs(game.surfaces) do
        for _, data_name in pairs(surface_queues) do
            local data = global[data_name][surface.index]
            if type(data)=="table" then
                -- log(serpent.block(data))
                global_stats[surface.name .. ":" .. data_name] = table_size(data)
            else
                global_stats[surface.name .. ":" .. data_name] = tostring(data)
            end
        end
    end
    return global_stats
end

me.help_text = function()
    game.print('Constructron-Continued command help:')
    game.print('/ctron help - show this help message')
    game.print('/ctron (enable|disable) (debug|construction|deconstruction|upgrade|repair|all) - toggle job types.')
    game.print('/ctron reset (settings|queues|entities|all)')
    game.print('/ctron clear all - clears all jobs, queued jobs and unprocessed entities')
    game.print('/ctron stats for a basic display of queue length')
    game.print('See Factorio mod portal for further assistance https://mods.factorio.com/mod/Constructron-Continued')
end

return me