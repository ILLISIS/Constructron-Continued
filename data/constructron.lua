
-------------------------------------------------------------------------------
-- Entity
-------------------------------------------------------------------------------

local args = {
    name = "constructron",
    scale = 1,
    leg_scale = 1,
    leg_movement_speed = 1,
    leg_thickness = 1,
}

create_spidertron(args)

-------------------------------------------------------------------------------
-- Item
-------------------------------------------------------------------------------

local constructron_item = {
    icons = {
        {
            icon = "__Constructron-Continued__/graphics/icon_texture.png",
            icon_size = 256,
            scale = 0.25
        },
        {
            icon = "__base__/graphics/icons/spidertron.png",
            icon_size = 64,
            icon_mipmaps = 4,
            scale = 0.9
        }
    },
    name = "constructron",
    order = "b[personal-transport]-c[spidertron]-a[spider]b",
    place_result = "constructron",
    stack_size = 1,
    subgroup = "transport",
    type = "item-with-entity-data"
}

local constructron_recipe = {
    type = "recipe",
    name = "constructron",
    enabled = false,
    ingredients = {
        {type = "item", name = "spidertron", amount = 1}
    },
    results = {
        {type = "item", name = "constructron", amount = 1}
    },
    energy = 1
}

-------------------------------------------------------------------------------
-- Technology
-------------------------------------------------------------------------------

table.insert(
    data.raw["technology"]["spidertron"].effects,{
        type = "unlock-recipe",
        recipe = "constructron"
    }
)

--------
data:extend({constructron_item})
data:extend({constructron_recipe})