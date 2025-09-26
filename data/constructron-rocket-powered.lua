
------------------------------------------------------------------------------
-- Entity
-------------------------------------------------------------------------------

local args = {
    name = "constructron-rocket-powered",
    scale = 1,
    leg_scale = 1,
    leg_movement_speed = 1,
    leg_thickness = 1,
}

local spider_leg = {
	type = "spider-leg",
	name = "constructron-rocket-powered-leg",
	localised_name = {"entity-name.spidertron-leg"},
	collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
	selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
	icon = "__base__/graphics/icons/spidertron.png",
	collision_mask = { layers = { } },
	target_position_randomisation_distance = 0.25,
	minimal_step_size = 4,
	stretch_force_scalar = 1,
	knee_height = 2.5,
	knee_distance_factor = 0.4,
	initial_movement_speed = 100,
	movement_acceleration = 100,
	max_health = 100,
	base_position_selection_distance = 6,
	movement_based_position_selection_distance = 4,
	selectable_in_game = false,
	alert_when_damaged = false,
}
data:extend({spider_leg})

create_spidertron(args)

-- remove legs from the spidertron entity
local spidertron = data.raw["spider-vehicle"]["constructron-rocket-powered"]
spidertron.spider_engine.legs = { 	-- 1
	leg = "constructron-rocket-powered-leg",
	mount_position = {0, -1},
	ground_position = {0, -1},
	walking_group = 1,
}

if mods["Krastorio2"] then
    spidertron.equipment_grid = "kr-spidertron-equipment-grid"
end

-------------------------------------------------------------------------------
-- Item
-------------------------------------------------------------------------------

local constructron_item = {
    icons = {
        {
            icon = "__Constructron-Continued__/graphics/icon_texture_gray.png",
            icon_size = 256,
            scale = 0.12
        },
        {
            icon = "__base__/graphics/icons/spidertron.png",
            icon_size = 64,
            icon_mipmaps = 4,
            scale = 0.45
        }
    },
    name = "constructron-rocket-powered",
    order = "b[personal-transport]-c[spidertron]-a[spider]b",
    place_result = "constructron-rocket-powered",
    stack_size = 1,
    subgroup = "transport",
    type = "item-with-entity-data"
}

local constructron_recipe = {
    type = "recipe",
    name = "constructron-rocket-powered",
    enabled = false,
    ingredients = {
        {type = "item", name = "spidertron", amount = 1},
		{type = "item", name = "jetpack-1", amount = 4},
    },
    results = {
        {type = "item", name = "constructron-rocket-powered", amount = 1},
    },
    energy = 1
}

-------------------------------------------------------------------------------
-- Technology
-------------------------------------------------------------------------------

table.insert(
    data.raw["technology"]["spidertron"].effects,{
        type = "unlock-recipe",
        recipe = "constructron-rocket-powered"
    }
)

-------------------------------------------------------------------------------
-- Extend
-------------------------------------------------------------------------------

data:extend({constructron_item})
data:extend({constructron_recipe})