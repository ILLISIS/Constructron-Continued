require("data/lib/lib_copy_spider")

local name, ctron = create_copy_spidertron("spidertronmk2")

data:extend(ctron)

table.insert(
    data.raw["technology"]["spidertron"].effects,
    {
        type = "unlock-recipe",
        recipe = name
    }
)

local name, ctron = create_copy_spidertron("spidertronmk3")

data:extend(ctron)

table.insert(
    data.raw["technology"]["spidertron"].effects,
    {
        type = "unlock-recipe",
        recipe = name
    }
)