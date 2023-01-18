local tech = data.raw["technology"]["spidertron"]

local unit = tech.unit
unit.count = 450
unit.time = 60

local ctron_tech = {
    type = "technology",
    name = "constructron",
    prerequisites = {
        "spidertron",
        "personal-roboport-equipment"
    },
    unit = unit,
    effects = {},

    icon = tech.icon,
    icon_mipmaps = tech.icon_mipmaps,
    icon_size = tech.icon_size
}

data:extend({ctron_tech})
