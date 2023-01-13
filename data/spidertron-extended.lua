require("data/lib/lib_copy_spider")

local name, ctron = create_copy_spidertron("spidertronmk2")

-- Add the 'Cannot be placed on:' SE description
if mods["space-exploration"] then
    ctron.localised_description = {""}
    local data_util = require("__space-exploration__/data_util")
    data_util.collision_description(ctron)
end

data:extend(ctron)

table.insert(
    data.raw["technology"]["spidertron"].effects,
    {
        type = "unlock-recipe",
        recipe = name
    }
)



name, ctron = create_copy_spidertron("spidertronmk3")

-- Add the 'Cannot be placed on:' SE description
if mods["space-exploration"] then
    ctron.localised_description = {""}
    local data_util = require("__space-exploration__/data_util")
    data_util.collision_description(ctron)
end

data:extend(ctron)

table.insert(
    data.raw["technology"]["spidertron"].effects,
    {
        type = "unlock-recipe",
        recipe = name
    }
)