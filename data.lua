require("prototypes/constructron")
require("prototypes/constructron_pathing_proxy")
require("prototypes/service_station")

require("prototypes/technology")

if mods["space-exploration"] and settings.startup["enable_rocket_powered_constructron"].value then
    require("prototypes/constructron-rocket-powered")
end