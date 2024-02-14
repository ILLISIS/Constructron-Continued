local ctron = require("script/constructron")

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
    settings.global["job-start-delay"] = {value = 5}
    settings.global["horde_mode"] = {value = false}
end

me.clear_queues = function()
    global.construction_entities = {}
    global.deconstruction_entities = {}
    global.upgrade_entities = {}
    global.repair_entities = {}

    global.construction_index = 0
    global.deconstruction_index = 0
    global.updgrade_index = 0
    global.repair_index = 0

    global.construction_queue = {}
    global.deconstruction_queue = {}
    global.upgrade_queue = {}
    global.repair_queue = {}

    for _, surface in pairs(game.surfaces) do
        global.construction_queue[surface.index] = global.construction_queue[surface.index] or {}
        global.deconstruction_queue[surface.index] = global.deconstruction_queue[surface.index] or {}
        global.upgrade_queue[surface.index] = global.upgrade_queue[surface.index] or {}
        global.repair_queue[surface.index] = global.repair_queue[surface.index] or {}
    end
end

me.clear_single_job_type = function(job_type)
    global[job_type .. '_entities'] = {}
    global[job_type ..'_index'] = 0
    global[job_type .. '_queue'] = {}
    for _, surface in pairs(game.surfaces) do
        global[job_type .. '_queue'][surface.index] = {}
    end
end

me.reacquire_construction_jobs = function()
    if not settings.global["construct_jobs"] then return end
    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered {
            name = {"entity-ghost", "tile-ghost", "item-request-proxy"},
            force = {"player", "neutral"},
            surface = surface.name
        }
        game.print('found '.. #entities ..' entities on '.. surface.name ..' to construct.')
        for _, entity in ipairs(entities) do
            global.construction_index = global.construction_index + 1
            global.construction_entities[global.construction_index] = entity
        end
        global.construction_tick = game.tick
        global.entity_proc_trigger = true
    end
end

me.reacquire_deconstruction_jobs = function()
    if not settings.global["deconstruct_jobs"] then return end
    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered {
            to_be_deconstructed = true,
            force = {"player", "neutral"},
            surface = surface.name
        }
        game.print('found '.. #entities ..' entities on '.. surface.name ..' to deconstruct.')
        for _, entity in ipairs(entities) do
            global.deconstruction_index = global.deconstruction_index + 1
            global.deconstruction_entities[global.deconstruction_index] = entity
        end
        global.deconstruction_tick = game.tick
        global.entity_proc_trigger = true
    end
end

me.reacquire_upgrade_jobs = function()
    if not settings.global["upgrade_jobs"] then return end
    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered {
            to_be_upgraded = true,
            force = "player",
            surface = surface.name
        }
        game.print('found '.. #entities ..' entities on '.. surface.name ..' to upgrade.')
        for _, entity in ipairs(entities) do
            global.upgrade_index = global.upgrade_index + 1
            global.upgrade_entities[global.upgrade_index] = entity
        end
        global.upgrade_tick = game.tick
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

    -- determine manage surfaces
    me.reset_managed_surfaces()
end

me.reset_managed_surfaces = function()
    global.managed_surfaces = {}
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        if (global.constructrons_count[surface_index] > 0) and (global.stations_count[surface_index] > 0) then
            global.managed_surfaces[game.surfaces[surface_index].name] = surface_index
        else
            global.managed_surfaces[game.surfaces[surface_index].name] = nil
        end
    end
end

me.reacquire_stations = function()
    for _, surface in pairs(game.surfaces) do
        global.stations_count[surface.index] = 0
        local stations = surface.find_entities_filtered {
            name = "service_station",
            force = "player",
            surface = surface.name
        }

        for _, station in pairs(stations) do
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
    for _, surface in pairs(game.surfaces) do
        global.constructrons_count[surface.index] = 0
        local constructrons = surface.find_entities_filtered {
            name = {"constructron", "constructron-rocket-powered"},
            force = "player",
            surface = surface.name
        }

        for _, constructron in pairs(constructrons) do
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
            constructron.grid.inhibit_movement_bonus = false

            local grid = constructron.grid
            if grid then
                for _, eq in next, grid.equipment do
                    if eq.type == "roboport-equipment" then
                        local old_eq_name = eq.prototype.take_result.name
                        local old_eq_pos = eq.position
                        local old_eq_energy = eq.energy
                        grid.take{ position = eq.position }
                        local new_set = grid.put{ name = old_eq_name, position = old_eq_pos }
                        if new_set then
                            new_set.energy = old_eq_energy
                        end
                    end
                end
            end

            global.constructrons_count[surface.index] = global.constructrons_count[surface.index] + 1
        end
        game.print('Registered ' .. global.constructrons_count[surface.index] .. ' constructrons on ' .. surface.name .. '.')
    end
end

me.reload_ctron_status = function()
    for _, constructron in pairs(global.constructrons) do
        ctron.set_constructron_status(constructron, 'busy', false)
    end
end

me.reload_ctron_color = function()
    for _, constructron in pairs(global.constructrons) do
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
                constructron.autopilot_destination = nil
                local closest_station = ctron.get_closest_service_station(constructron)
                if closest_station then
                    global.job_index = global.job_index + 1
                    global.jobs[global.job_index] = job.new(global.job_index, constructron.surface.index, "upgrade", constructron)
                    global.jobs[global.job_index].state = "finishing"
                    global.job_proc_trigger = true -- start job operations
                end
            end
        else
            game.print('No stations to recall Constructrons to on ' .. surface.name .. '.')
        end
    end
end

me.clear_ctron_inventory = function()
    local slot = 1

    for _, constructron in pairs(global.constructrons) do
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
    local autoplace_entities = game.get_filtered_entity_prototypes{{filter="autoplace"}}
    for _, entity in pairs(autoplace_entities) do
        if entity.mineable_properties and entity.mineable_properties.products then
            global.allowed_items[entity.mineable_properties.products[1].name] = true
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
end

me.stats = function()
    local queues = {
        "registered_entities",
        "constructron_statuses",
        "construction_entities",
        "deconstruction_entities",
        "upgrade_entities",
        "repair_entities",
        "jobs",
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
        "construction_queue",
        "deconstruction_queue",
        "upgrade_queue",
        "repair_queue",
    }
    for _, surface in pairs(game.surfaces) do
        for _, data_name in pairs(surface_queues) do
            local data = global[data_name][surface.index]
            if type(data)=="table" then
                -- log(serpent.block(data))
                global_stats[surface.name .. ": " .. data_name] = table_size(data)
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
    game.print('/ctron clear (all|construction|deconstruction|upgrade|repair)')
    game.print('/ctron stats for a basic display of queue length')
    game.print('See Factorio mod portal for further assistance https://mods.factorio.com/mod/Constructron-Continued')
end

return me