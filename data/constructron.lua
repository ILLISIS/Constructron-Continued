local lib_spider = require("data/lib/lib_spider")

-------------------------------------------------------------------------------
-- Entity
-------------------------------------------------------------------------------

local constructron_collision_mask = {}
local constructron_leg_collision_mask = {
    "player-layer",
    "rail-layer"
}

if mods["space-exploration"] then
    local collision_mask_util_extended = require("__space-exploration__/collision-mask-util-extended/data/collision-mask-util-extended")

    -- removed becuase it caused despawns when constructrons built space ship tiles. (pathfinder still collides)
    -- local spaceship_collision_layer = collision_mask_util_extended.get_named_collision_mask("moving-tile")
    -- table.insert(constructron_leg_collision_mask, spaceship_collision_layer)

    --collide with all of "space"
    local collision_mask_space_tile = collision_mask_util_extended.get_named_collision_mask("space-tile")
    table.insert(constructron_leg_collision_mask, collision_mask_space_tile)
end

local constructron_definition = {
    name = "constructron",
    collision_mask = constructron_collision_mask
}

local constructron_leg_definition = {
    name = "constructron",
    collision_mask = constructron_leg_collision_mask
}

if mods["Krastorio2"] then
    constructron_definition.equipment_grid = "kr-spidertron-equipment-grid"
end

local constructron = lib_spider.create_spidertron(constructron_definition)
local leg_entities = lib_spider.create_spidertron_legs(constructron_leg_definition)

-------------------------------------------------------------------------------
-- Item
-------------------------------------------------------------------------------

local constructron_item = {
    icons = {
        {
            icon = "__Constructron-Continued__/graphics/icon_texture.png",
            icon_size = 256,
            -- scale = 0.25
        },
        {
            icon = "__base__/graphics/icons/spidertron.png",
            icon_size = 64,
            icon_mipmaps = 4,
            scale = 0.5
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
        {"spidertron", 1}
    },
    result = "constructron",
    result_count = 1,
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

-------------------------------------------------------------------------------
-- Extend
-------------------------------------------------------------------------------

-- Add the 'Cannot be placed on:' SE description
if mods["space-exploration"] then
    constructron.localised_description = {""}
    local data_util = require("__space-exploration__/data_util")
    data_util.collision_description(constructron)
end

local ctron_classic = {constructron, constructron_item}
table.insert(ctron_classic, constructron_recipe)

for _, leg in pairs(leg_entities) do
    table.insert(ctron_classic, leg)
end

data:extend(ctron_classic)