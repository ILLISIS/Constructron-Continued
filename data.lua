require("data/constructron")
require("data/constructron_pathing_proxy")
require("data/service_station")
require("data/styles")

if mods["space-exploration"] and settings.startup["enable_rocket_powered_constructron"].value then
    require("data/constructron-rocket-powered")
end
