require("__Constructron-Continued__.data.constructron")
require("__Constructron-Continued__.data.constructron_pathing_proxy")
require("__Constructron-Continued__.data.service_station")
if mods["space-exploration"] and settings.startup["enable_rocket_powered_constructron"].value then
    require("__Constructron-Continued__.data.constructron-rocket-powered")
end
