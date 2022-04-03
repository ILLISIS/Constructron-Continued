global.registered_entities = {}

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

---

for s, surface in pairs(game.surfaces) do
    global.constructrons_count[surface.index] = 0
    local constructrons = surface.find_entities_filtered {
        name = "constructron",
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

        global.constructrons_count[surface.index] = global.constructrons_count[surface.index] + 1
    end
    game.print('Registered ' .. global.constructrons_count[surface.index] .. ' constructrons on ' .. surface.name .. '.')
end