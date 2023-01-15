require("data/lib/lib_copy_spider")

local name, ctron = create_copy_spidertron("ss-space-spidertron")

data:extend(ctron)

table.insert(
    data.raw["technology"]["spidertron"].effects,
    {
        type = "unlock-recipe",
        recipe = name
    }
)
