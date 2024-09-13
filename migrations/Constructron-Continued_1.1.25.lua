
global.station_requests = global.station_requests or {}
for _, station in pairs(global.service_stations) do
    global.station_requests[station.unit_number] = global.station_requests[station.unit_number] or {}
end

global.cargo_index = global.cargo_index or 0

global.cargo_queue = global.cargo_queue or {}
for _, surface in pairs(game.surfaces) do
    global.cargo_queue[surface.index] = global.cargo_queue[surface.index] or {}
end

global.user_interface = global.user_interface or {}
for _, player in pairs(game.players) do
    global.user_interface[player.index] = global.user_interface[player.index] or {
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
        }
    }
    global.user_interface[player.index].cargo_ui = {
        elements = {}
    }
    global.user_interface[player.index].logistics_ui = {
        elements = {}
    }
end

-------------------------------------------------------------------------------
game.print('Constructron-Continued: v1.1.25 migration complete!')