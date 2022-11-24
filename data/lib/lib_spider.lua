-- luacheck: ignore
-- passing luacheck requires refactoring of spidertron_animations, movement_triggers, sounds and hit_effects
local hit_effects = require("__base__/prototypes/entity/hit-effects")
local sounds = require("__base__/prototypes/entity/sounds")
local movement_triggers = require("__base__/prototypes/entity/movement-triggers")

local lib_spider = {}
lib_spider.spidertron_animations = require("data/lib/lib_spider_animations")
lib_spider.default_legs = {
    -- right side
    {
        block = {2},
        angle = 138,
        length = 3.3
    },
    {
        block = {1, 3},
        angle = 108,
        length = 3.1
    },
    {
        block = {2, 4},
        angle = 72,
        length = 3.1
    },
    {
        block = {3},
        angle = 42,
        length = 3.3
    }, -- left side
    {
        block = {6, 1},
        angle = -138,
        length = 3.3
    },
    {
        block = {5, 7},
        angle = -108,
        length = 3.1
    },
    {
        block = {6, 8},
        angle = -72,
        length = 3.1
    },
    {
        block = {7},
        angle = -42,
        length = 3.3
    }
}

function lib_spider.create_spidertron(arguments)
    local entity_name = arguments.name
    local scale = arguments.scale or 1
    local leg_scale = scale * (arguments.leg_scale or 1)
    local grid = arguments.grid or "spidertron-equipment-grid"
    local mining_result = arguments.name or "spidertron"
    local burner = arguments.burner
    local energy_source = arguments.energy_source
    local allow_passengers = arguments.allow_passengers or true
    local collision_mask = arguments.collision_mask or {}

    if not burner and not energy_source then
        energy_source = {
            type = "void"
        }
    end
    local movement_energy_consumption = arguments.movement_energy_consumption or "250kW"
    local guns = arguments.guns or {"spidertron-rocket-launcher-1", "spidertron-rocket-launcher-2", "spidertron-rocket-launcher-3", "spidertron-rocket-launcher-4"}
    local inventory_size = arguments.inventory_size or 80
    local trash_inventory_size = arguments.trash_inventory_size or 20
    local legs = arguments.legs or lib_spider.default_legs
    local function get_leg_hit_the_ground_trigger()
        return {
            {
                type = "create-trivial-smoke",
                smoke_name = "smoke-building",
                repeat_count = 4,
                starting_frame_deviation = 5,
                starting_frame_speed_deviation = 5,
                offset_deviation = {{-0.2, -0.2}, {0.2, 0.2}},
                speed_from_center = 0.03
            }
        }
    end
    local function get_engine_leg(i, alpha, length, blocking_legs)
        alpha = alpha / 360 * 2 * math.pi
        local pos = {
            x = math.sin(alpha),
            y = math.cos(alpha)
        }
        local leg = {
            leg = entity_name .. "-leg-" .. i,
            mount_position = util.by_pixel(math.floor(pos.x * 0.875 * 32 + 0.5) * scale, math.floor(pos.y * 0.875 * 32 + 0.5) * scale), -- {-0.5, 0.75},
            ground_position = {pos.x * length * leg_scale, pos.y * length * leg_scale},
            blocking_legs = blocking_legs,
            leg_hit_the_ground_trigger = get_leg_hit_the_ground_trigger()
        }
        return leg
    end

    local entity = {
        type = "spider-vehicle",
        name = entity_name,
        collision_box = {{-1 * scale, -1 * scale}, {1 * scale, 1 * scale}},
        sticker_box = {{-1.5 * scale, -1.5 * scale}, {1.5 * scale, 1.5 * scale}},
        selection_box = {{-1 * scale, -1 * scale}, {1 * scale, 1 * scale}},
        drawing_box = {{-3 * scale, -4 * scale}, {3 * scale, 2 * scale}},
        icon = "__base__/graphics/icons/spidertron.png",
        mined_sound = {
            filename = "__core__/sound/deconstruct-large.ogg",
            volume = 0.8
        },
        open_sound = {
            filename = "__base__/sound/spidertron/spidertron-door-open.ogg",
            volume = 0.35
        },
        close_sound = {
            filename = "__base__/sound/spidertron/spidertron-door-close.ogg",
            volume = 0.4
        },
        sound_minimum_speed = 0.1,
        sound_scaling_ratio = 0.6,
        working_sound = {
            sound = {
                filename = "__base__/sound/spidertron/spidertron-vox.ogg",
                volume = 0.35
            },
            activate_sound = {
                filename = "__base__/sound/spidertron/spidertron-activate.ogg",
                volume = 0.5
            },
            deactivate_sound = {
                filename = "__base__/sound/spidertron/spidertron-deactivate.ogg",
                volume = 0.5
            },
            match_speed_to_activity = true
        },
        icon_size = 64,
        icon_mipmaps = 4,
        weight = 1,
        braking_force = 1,
        friction_force = 1,
        flags = {"placeable-neutral", "player-creation", "placeable-off-grid"},
        collision_mask = collision_mask,
        minable = {
            mining_time = 0.5,
            result = mining_result
        },
        max_health = 3000,
        resistances = {
            {
                type = "fire",
                decrease = 15,
                percent = 60
            },
            {
                type = "physical",
                decrease = 15,
                percent = 60
            },
            {
                type = "impact",
                decrease = 50,
                percent = 80
            },
            {
                type = "explosion",
                decrease = 20,
                percent = 75
            },
            {
                type = "acid",
                decrease = 0,
                percent = 70
            },
            {
                type = "laser",
                decrease = 0,
                percent = 70
            },
            {
                type = "electric",
                decrease = 0,
                percent = 70
            }
        },
        minimap_representation = {
            filename = "__base__/graphics/entity/spidertron/spidertron-map.png",
            flags = {"icon"},
            size = {128, 128},
            scale = 0.5
        },
        corpse = "spidertron-remnants",
        dying_explosion = "spidertron-explosion",
        energy_per_hit_point = 1,
        guns = guns,
        inventory_size = inventory_size,
        equipment_grid = grid,
        allow_passengers = allow_passengers,
        trash_inventory_size = trash_inventory_size,
        height = 1.5 * scale * leg_scale,
        torso_rotation_speed = 0.005,
        chunk_exploration_radius = 3,
        selection_priority = 51,
        graphics_set = lib_spider.spidertron_animations.spidertron_torso_graphics_set(scale),
        energy_source = energy_source,
        burner = burner,
        movement_energy_consumption = movement_energy_consumption,
        automatic_weapon_cycling = true,
        chain_shooting_cooldown_modifier = 0.5,
        spider_engine = {
            legs = {},
            military_target = "spidertron-military-target"
        }
    }
    log("legs_#" .. #legs)
    for x = 1, #legs do
        table.insert(entity.spider_engine.legs, get_engine_leg(x, legs[x].angle, legs[x].length, legs[x].block))
    end

    return entity
end

function lib_spider.make_spidertron_leg(spidertron_name, scale, leg_thickness, movement_speed, number, base_sprite, ending_sprite)
    if scale == 0 then
        part_length = 1
    else
        part_length = 3.5 * scale
    end
    return {
        type = "spider-leg",
        name = spidertron_name .. "-leg-" .. number,
        localised_name = {"entity-name.spidertron-leg"},
        collision_box = {{-0.05, -0.05}, {0.05, 0.05}},
        selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
        icon = "__base__/graphics/icons/spidertron.png",
        icon_size = 64,
        icon_mipmaps = 4,
        walking_sound_volume_modifier = 0.6,
        target_position_randomisation_distance = 0.25 * scale,
        minimal_step_size = 1 * scale,
        working_sound = {
            match_progress_to_activity = true,
            sound = sounds.spidertron_leg,
            audible_distance_modifier = 0.5
        },
        part_length = part_length,
        initial_movement_speed = 0.06 * movement_speed,
        movement_acceleration = 0.03 * movement_speed,
        max_health = 100,
        movement_based_position_selection_distance = 4 * scale,
        selectable_in_game = false,
        graphics_set = lib_spider.spidertron_animations.create_spidertron_leg_graphics_set(scale * leg_thickness, number)
    }
end

function lib_spider.create_spidertron_legs(arguments)
    local legs = arguments.legs or lib_spider.default_legs
    local scale = arguments.scale or 1
    local leg_movement_speed = arguments.leg_movement_speed or 1
    local leg_thickness = arguments.leg_thickness or 1
    local leg_scale = scale * (arguments.leg_scale or 1)
    local collision_mask = arguments.collision_mask or {}
    local leg_entities = {}
    for x = 1, #legs do
        local leg_details = legs[x]
        local custom_scale, custom_leg_thickness
        if leg_details.scale then
            custom_scale = leg_details.scale
            custom_leg_thickness = 1 / custom_scale * leg_thickness
        end
        local leg = lib_spider.make_spidertron_leg(arguments.name, (custom_scale or leg_scale), (custom_leg_thickness or leg_thickness), leg_movement_speed, x)
        leg.collision_mask = collision_mask
        table.insert(leg_entities, leg)
    end
    return leg_entities
end

return lib_spider
