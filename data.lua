require("data/constructron")
require("data/constructron_pathing_proxy")
require("data/service_station")
require("data/station_combinator")
require("data/selection_tool")
require("data/shortcut")
require("data/custom_input")

if mods["space-exploration"] and settings.startup["enable_rocket_powered_constructron"].value then
    require("data/constructron-rocket-powered")
end

require("data/compatibility/nullius")
