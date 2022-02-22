global.registered_entities = global.registered_entities or {}

for c, constructron in pairs(global.constructrons) do
    local registration_number = script.register_on_entity_destroyed(constructron)
    global.registered_entities[registration_number] = "constructron"
    DebugLog('Migration c registered!')
end

for s, station in pairs(global.service_stations) do
    local registration_number = script.register_on_entity_destroyed(station)
    global.registered_entities[registration_number] = "service_station"
    DebugLog('Migration s registered!')
end