local lib_spider = require("prototypes/lib/spider")
local spidertron_definition = {
    name = "constructron-rocket-powered",
    guns = {},
    scale = 1,
    leg_scale = 0,
    legs = {
        {
            block = { 1 },
            angle = 0,
            length = 1
        }
    },
    collision_mask = { "colliding-with-tiles-only", "ground-tile", "water-tile" }
}
local constructron = lib_spider.create_spidertron(spidertron_definition)
constructron.se_allow_in_space = true

--Rocket flames
-- local layers = constructron.graphics_set.base_animation.layers
-- for _, layer in pairs(layers) do
--     layer.repeat_count = 8
--     layer.hr_version.repeat_count = 8
-- end
-- table.insert(
--     layers,
--     1,
--     {
--         filename = "__base__/graphics/entity/rocket-silo/10-jet-flame.png",
--         priority = "medium",
--         blend_mode = "additive",
--         draw_as_glow = true,
--         width = 87,
--         height = 128,
--         frame_count = 8,
--         line_length = 8,
--         animation_speed = 0.5,
--         scale = 1.25,
--         shift = util.by_pixel(-0.5, 55),
--         direction_count = 1,
--         hr_version = {
--             filename = "__base__/graphics/entity/rocket-silo/hr-10-jet-flame.png",
--             priority = "medium",
--             blend_mode = "additive",
--             draw_as_glow = true,
--             width = 172,
--             height = 256,
--             frame_count = 8,
--             line_length = 8,
--             animation_speed = 0.5,
--             scale = 1.25 / 2,
--             shift = util.by_pixel(-1, 80),
--             direction_count = 1
--         }
--     }
-- )

local leg_entities = lib_spider.create_spidertron_legs(spidertron_definition)

local constructron_item = {
    icons = {
        {
            icon = "__Constructron-Continued__/graphics/icon_texture_gray.png",
            icon_size = 256,
            scale = 0.25
        },
        {
            icon = "__base__/graphics/icons/spidertron.png",
            icon_size = 64,
            icon_mipmaps = 4,
            scale = 1
        }
    },
    name = "constructron-rocket-powered",
    order = "b[personal-transport]-c[spidertron]-a[spider]b",
    place_result = "constructron-rocket-powered",
    stack_size = 1,
    subgroup = "transport",
    type = "item-with-entity-data"
}

local constructron_recipe
local constructron_easy_recipe

constructron_recipe = {
    type = "recipe",
    name = "constructron-rocket-powered",
    enabled = false,
    ingredients = {
        { "low-density-structure",   150 },
        { "se-heavy-girder",         16 },
        { "rocket-control-unit",     16 },
        { "se-specimen",             1 },
        { "rocket-launcher",         4 },
        { "se-rtg-equipment",        8 },
        { "radar",                   2 },
        { "se-cargo-rocket-section", 200 }
    },
    result = "constructron-rocket-powered",
    result_count = 1,
    energy = 1
}
constructron_easy_recipe = {
    type = "recipe",
    name = "constructron-rocket-powered",
    enabled = false,
    ingredients = {
        { "constructron",            1 },
        { "se-cargo-rocket-section", 200 }
    },
    result = "constructron-rocket-powered",
    result_count = 1,
    energy = 1
}

if mods["space-exploration"] then
    local ctron_rocket_powered = { constructron, constructron_item }
    if settings.startup["constructron-easy-recipe-toggle"].value then
        table.insert(ctron_rocket_powered, constructron_easy_recipe)
    else
        table.insert(ctron_rocket_powered, constructron_recipe)
    end
    for _, leg in pairs(leg_entities) do
        leg.se_allow_in_space = true
        table.insert(ctron_rocket_powered, leg)
    end

    data:extend(ctron_rocket_powered)

    table.insert(
        data.raw["technology"]["constructron"].effects,
        {
            type = "unlock-recipe",
            recipe = "constructron-rocket-powered"
        }
    )
end
