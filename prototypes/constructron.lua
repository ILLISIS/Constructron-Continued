local lib_spider = require("prototypes/lib/spider")

local constructron_collision_mask = {
    "water-tile",
    "colliding-with-tiles-only",
    "not-colliding-with-itself"
}

local spidertron_definition = {
    name = "constructron",
    collision_mask = constructron_collision_mask,
    allow_passengers = false
}
local constructron = lib_spider.create_spidertron(spidertron_definition)

local leg_entities = lib_spider.create_spidertron_legs(spidertron_definition)

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
            scale = 1
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
        { "raw-fish",                 1 },
        { "rocket-control-unit",      16 },
        { "low-density-structure",    150 },
        { "effectivity-module-3",     2 },
        { "rocket-launcher",          4 },
        { "fusion-reactor-equipment", 2 },
        { "exoskeleton-equipment",    4 },
        { "radar",                    2 }
    },
    result = "constructron",
    result_count = 1,
    energy = 1
}

local constructron_easy_recipe = {
    type = "recipe",
    name = "constructron",
    enabled = false,
    ingredients = {
        { "spidertron", 1 }
    },
    result = "constructron",
    result_count = 1,
    energy = 1
}

local ctron_classic = { constructron, constructron_item }
if settings.startup["constructron-easy-recipe-toggle"].value then
    table.insert(ctron_classic, constructron_easy_recipe)
else
    table.insert(ctron_classic, constructron_recipe)
end
for _, leg in pairs(leg_entities) do
    table.insert(ctron_classic, leg)
end

data:extend(ctron_classic)

table.insert(data.raw["technology"]["constructron"].effects, { type = "unlock-recipe", recipe = "constructron" })
