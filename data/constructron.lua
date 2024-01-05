local lib_spider = require("data/lib/lib_spider")

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

    if settings.startup["enable_rocket_powered_constructron"].value then
        --collide with all of "space"
        local collision_mask_space_tile = collision_mask_util_extended.get_named_collision_mask("space-tile")
        table.insert(constructron_leg_collision_mask, collision_mask_space_tile)
    else
        --collide with "empty space"
        local empty_space_collision_layer = collision_mask_util_extended.get_named_collision_mask("empty-space-tile")
        table.insert(constructron_leg_collision_mask, empty_space_collision_layer)
    end
end

local constructron_definition = {
    name = "constructron",
    collision_mask = constructron_collision_mask
}

local constructron_leg_definition = {
    name = "constructron",
    collision_mask = constructron_leg_collision_mask
}

local constructron = lib_spider.create_spidertron(constructron_definition)

local leg_entities = lib_spider.create_spidertron_legs(constructron_leg_definition)

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
local constructron_recipe
local constructron_easy_recipe

if not mods["space-exploration"] then
    constructron_recipe = {
        type = "recipe",
        name = "constructron",
        enabled = false,
        ingredients = {
            {"raw-fish", 1},
            {"rocket-control-unit", 16},
            {"low-density-structure", 150},
            {"effectivity-module-3", 2},
            {"rocket-launcher", 4},
            {"fusion-reactor-equipment", 2},
            {"exoskeleton-equipment", 4},
            {"radar", 2}
        },
        result = "constructron",
        result_count = 1,
        energy = 1
    }
    constructron_easy_recipe = {
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
else
    constructron_recipe = {
        type = "recipe",
        name = "constructron",
        enabled = false,
        ingredients = {
            {"low-density-structure", 150},
            {"se-heavy-girder", 16},
            {"rocket-control-unit", 16},
            {"se-specimen", 1},
            {"rocket-launcher", 4},
            {"se-rtg-equipment", 8},
            {"exoskeleton-equipment", 4},
            {"radar", 2}
        },
        result = "constructron",
        result_count = 1,
        energy = 1
    }
    constructron_easy_recipe = {
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
end


-- Add the 'Cannot be placed on:' SE description
if mods["space-exploration"] then
    constructron.localised_description = {""}
    local data_util = require("__space-exploration__/data_util")
    data_util.collision_description(constructron)
end

local ctron_classic = {constructron, constructron_item}
if settings.startup["constructron-easy-recipe-toggle"].value then
    table.insert(ctron_classic, constructron_easy_recipe)
else
    table.insert(ctron_classic, constructron_recipe)
end
for _, leg in pairs(leg_entities) do
    table.insert(ctron_classic, leg)
end

data:extend(ctron_classic)

table.insert(
    data.raw["technology"]["spidertron"].effects,
    {
        type = "unlock-recipe",
        recipe = "constructron"
    }
)
