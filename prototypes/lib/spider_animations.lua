local util = require("util")
local me = {}
me.image_base = "__base__/graphics/entity/spidertron/"

local function create_leg_sprite_layer_definition(spidertron_scale, column, row, additions, sprite_definition)
    local tab = util.table.deepcopy(sprite_definition)
    tab.x = (tab.variation_count >= 8) and (tab.width * (column - 1)) or tab.x
    tab.y = tab.height * (row - 1)
    if tab.scale then
        tab.scale = tab.scale * spidertron_scale
    else
        tab.scale = spidertron_scale
    end
    if tab.shift then
        tab.shift[1] = tab.shift[1] * spidertron_scale
        tab.shift[2] = tab.shift[2] * spidertron_scale
    end
    tab.draw_as_shadow = additions.draw_as_shadow
    tab.apply_runtime_tint = additions.apply_runtime_tint
    tab.variation_count = nil
    if tab.hr_version then
        tab.hr_version.x = (tab.hr_version.variation_count >= 8) and (tab.hr_version.width * (column - 1)) or tab.hr_version.x
        tab.hr_version.y = tab.hr_version.height * (row - 1)
        tab.hr_version.x = tab.hr_version.width * (column - 1)
        tab.hr_version.draw_as_shadow = additions.draw_as_shadow
        tab.hr_version.apply_runtime_tint = additions.apply_runtime_tint
        tab.hr_version.variation_count = nil
        tab.hr_version.scale = tab.hr_version.scale * spidertron_scale
        if tab.hr_version.shift then
            tab.hr_version.shift[1] = tab.hr_version.shift[1] * spidertron_scale
            tab.hr_version.shift[2] = tab.hr_version.shift[2] * spidertron_scale
        end
    end
    return tab
end

local function create_leg_part_special(spidertron_scale, key, leg_index, graphics_definitions, part_base)
    local special = util.table.deepcopy(part_base)
    for layer_name, layer_definitions in pairs(graphics_definitions.layers) do
        for _, v in pairs(layer_definitions) do
            if v[key] then
                special[layer_name] = create_leg_sprite_layer_definition(spidertron_scale, leg_index, v.row, v, graphics_definitions[v.key])
            end
        end
    end
    return special
end

local function create_leg_part_shadow_graphics(spidertron_scale, leg_index, graphics_definitions, part_base)
    return create_leg_part_special(spidertron_scale, "draw_as_shadow", leg_index, graphics_definitions, part_base)
end

local function create_leg_part_water_reflection_graphics(spidertron_scale, leg_index, graphics_definitions, part_base)
    return create_leg_part_special(spidertron_scale, "draw_as_water_reflection", leg_index, graphics_definitions, part_base)
end

local function create_leg_part_graphics(spidertron_scale, leg_index, graphics_definitions, part_base)
    local tab = util.table.deepcopy(part_base)
    for layer_name, layer_definitions in pairs(graphics_definitions.layers) do
        for _, v in pairs(layer_definitions) do
            if (not v.draw_as_shadow) and (not v.draw_as_water_reflection) then
                tab[layer_name] = tab[layer_name] or {layers = {}}
                table.insert(tab[layer_name].layers, create_leg_sprite_layer_definition(spidertron_scale, leg_index, v.row, v, graphics_definitions[v.key]))
            end
        end
    end
    return tab
end

local function create_spidertron_light_cone(orientation, intensity, size, shift_adder)
    local shift = {x = 0, y = -14 + shift_adder}
    return {
        type = "oriented",
        minimum_darkness = 0.3,
        picture = {
            filename = "__core__/graphics/light-cone.png",
            priority = "extra-high",
            flags = {"light"},
            scale = 2,
            width = 200,
            height = 200
        },
        source_orientation_offset = orientation,
        --add_perspective = true,
        shift = shift,
        size = 2 * size,
        intensity = 0.6 * intensity,
        color = {r = 0.92, g = 0.77, b = 0.3}
    }
end

function me.get_leg_graphics_properties(scale, _)
    return {
        upper_part = {
            middle_offset_from_top = 0.35 * scale, -- offset length in tiles (= px / 32)
            middle_offset_from_bottom = 0.45 * scale,
            -- if sum of top_end_length and bottom_end_length is greater than length of leg segment, sprites will start to get squashed
            top_end_length = 0.75 * scale,
            bottom_end_length = 0.75 * scale
        },
        lower_part = {
            middle_offset_from_top = 0.45 * scale,
            middle_offset_from_bottom = 0.65 * scale,
            top_end_length = 1 * scale,
            bottom_end_length = 1 * scale
        }

        -- upper_part_shadow = {},  -- when not defined, upper_part definition is used
        -- lower_part_shadow = {},  -- when not defined, lower_part definition is used

        -- upper_part_water_reflection = {}, -- when not defined, upper_part definition is used
        -- lower_part_water_reflection = {}  -- when not defined, lower_part definition is used
    }
end

function me.get_spidertron_leg_joint_rotation_offsets(scale, index)
    if index <= 4 then
        return 0.25 * scale
    end
    return -0.25 * scale
end

local function get_part(name)
    local leg_part_template_layers = {
        top_end = {
            {key = "top_end", row = 1},
            {key = "top_end", row = 2, draw_as_shadow = true},
            {key = "top_end", row = 3, apply_runtime_tint = true},
            {key = "reflection_top_end", row = 1, draw_as_water_reflection = true}
        },
        middle = {
            {key = "middle", row = 1},
            {key = "middle", row = 2, draw_as_shadow = true},
            {key = "reflection_middle", row = 1, draw_as_water_reflection = true}
        },
        bottom_end = {
            {key = "bottom_end", row = 1},
            {key = "bottom_end", row = 2, draw_as_shadow = true},
            {key = "bottom_end", row = 3, apply_runtime_tint = true},
            {key = "reflection_bottom_end", row = 1, draw_as_water_reflection = true}
        }
    }
    local data = {
        leg_lower_part_graphics_definitions = {
            layers = leg_part_template_layers,
            top_end = {
                filename = me.image_base .. "legs/spidertron-legs-lower-end-A.png",
                width = 20,
                height = 50,
                variation_count = 8,
                shift = util.by_pixel(0, 20),
                hr_version = {
                    filename = me.image_base .. "legs/hr-spidertron-legs-lower-end-A.png",
                    width = 40,
                    height = 98,
                    variation_count = 8,
                    scale = 0.5,
                    shift = util.by_pixel(0.5, 19.5)
                }
            },
            middle = {
                filename = me.image_base .. "legs/spidertron-legs-lower-stretchable.png",
                width = 26,
                height = 192,
                variation_count = 8,
                scale = 0.5,
                shift = util.by_pixel(1, 0),
                hr_version = {
                    filename = me.image_base .. "legs/hr-spidertron-legs-lower-stretchable.png",
                    width = 50,
                    height = 384,
                    variation_count = 8,
                    scale = 0.25,
                    shift = util.by_pixel(0.5, 0)
                }
            },
            bottom_end = {
                filename = me.image_base .. "legs/spidertron-legs-lower-end-B.png",
                width = 18,
                height = 46,
                variation_count = 8,
                shift = util.by_pixel(0, -21),
                hr_version = {
                    filename = me.image_base .. "legs/hr-spidertron-legs-lower-end-B.png",
                    width = 34,
                    height = 92,
                    variation_count = 8,
                    scale = 0.5,
                    shift = util.by_pixel(0, -21)
                }
            },
            reflection_top_end = {
                filename = me.image_base .. "legs/spidertron-legs-lower-end-A-water-reflection.png",
                width = 56,
                height = 110,
                variation_count = 1,
                scale = 0.5,
                shift = util.by_pixel(1 * 0.5, 34 * 0.5)
            },
            reflection_middle = {
                filename = me.image_base .. "legs/spidertron-legs-lower-stretchable-water-reflection.png",
                width = 72,
                height = 384,
                variation_count = 1,
                scale = 0.25,
                shift = util.by_pixel(1 * 0.5, 0)
            },
            reflection_bottom_end = {
                filename = me.image_base .. "legs/spidertron-legs-lower-end-B-water-reflection.png",
                width = 52,
                height = 104,
                variation_count = 1,
                scale = 0.5,
                shift = util.by_pixel(0, -38 * 0.5)
            }
        },
        leg_upper_part_graphics_definitions = {
            layers = leg_part_template_layers,
            top_end = {
                filename = me.image_base .. "legs/spidertron-legs-upper-end-A.png",
                width = 22,
                height = 44,
                variation_count = 8,
                shift = util.by_pixel(0, 18),
                hr_version = {
                    filename = me.image_base .. "legs/hr-spidertron-legs-upper-end-A.png",
                    width = 42,
                    height = 86,
                    variation_count = 8,
                    scale = 0.5,
                    shift = util.by_pixel(0, 18)
                }
            },
            middle = {
                filename = me.image_base .. "legs/spidertron-legs-upper-stretchable.png",
                width = 30,
                height = 128,
                variation_count = 8,
                scale = 0.5,
                shift = util.by_pixel(-2, 0),
                hr_version = {
                    filename = me.image_base .. "legs/hr-spidertron-legs-upper-stretchable.png",
                    width = 60,
                    height = 256,
                    variation_count = 8,
                    scale = 0.25,
                    shift = util.by_pixel(-1.5, 0)
                }
            },
            bottom_end = {
                filename = me.image_base .. "legs/spidertron-legs-upper-end-B.png",
                width = 20,
                height = 30,
                variation_count = 8,
                shift = util.by_pixel(1, -9),
                hr_version = {
                    filename = me.image_base .. "legs/hr-spidertron-legs-upper-end-B.png",
                    width = 38,
                    height = 58,
                    variation_count = 8,
                    scale = 0.5,
                    shift = util.by_pixel(0.5, -9)
                }
            },
            reflection_top_end = {
                filename = me.image_base .. "legs/spidertron-legs-upper-end-A-water-reflection.png",
                width = 64,
                height = 96,
                variation_count = 1,
                scale = 0.5,
                shift = util.by_pixel(1 * 0.5, 31 * 0.5)
            },
            reflection_middle = {
                filename = me.image_base .. "legs/spidertron-legs-upper-stretchable-water-reflection.png",
                width = 80,
                height = 256,
                variation_count = 1,
                scale = 0.25,
                shift = util.by_pixel(-4 * 0.5, 0)
            },
            reflection_bottom_end = {
                filename = me.image_base .. "legs/spidertron-legs-upper-end-B-water-reflection.png",
                width = 56,
                height = 74,
                variation_count = 1,
                scale = 0.5,
                shift = util.by_pixel(1 * 0.5, -14 * 0.5)
            }
        },
        leg_joint_graphics_definitions = {
            filename = me.image_base .. "legs/spidertron-legs-knee.png",
            width = 12,
            height = 14,
            variation_count = 8,
            shift = util.by_pixel(1, 0),
            hr_version = {
                filename = me.image_base .. "legs/hr-spidertron-legs-knee.png",
                width = 22,
                height = 28,
                variation_count = 8,
                scale = 0.5,
                shift = util.by_pixel(0.5, 0)
            }
        }
    }
    return data[name]
end

function me.spidertron_torso_graphics_set(spidertron_scale)
    return {
        base_animation = {
            layers = {
                {
                    filename = me.image_base .. "torso/spidertron-body-bottom.png",
                    width = 64,
                    height = 54,
                    line_length = 1,
                    direction_count = 1,
                    scale = spidertron_scale,
                    shift = util.by_pixel(0 * spidertron_scale, 0 * spidertron_scale),
                    hr_version = {
                        filename = me.image_base .. "torso/hr-spidertron-body-bottom.png",
                        width = 126,
                        height = 106,
                        line_length = 1,
                        direction_count = 1,
                        scale = 0.5 * spidertron_scale,
                        shift = util.by_pixel(0 * spidertron_scale, 0 * spidertron_scale)
                    }
                },
                {
                    filename = me.image_base .. "torso/spidertron-body-bottom-mask.png",
                    width = 62,
                    height = 46,
                    line_length = 1,
                    direction_count = 1,
                    scale = spidertron_scale,
                    apply_runtime_tint = true,
                    shift = util.by_pixel(0 * spidertron_scale, 4 * spidertron_scale),
                    hr_version = {
                        filename = me.image_base .. "torso/hr-spidertron-body-bottom-mask.png",
                        width = 124,
                        height = 90,
                        line_length = 1,
                        direction_count = 1,
                        scale = 0.5 * spidertron_scale,
                        apply_runtime_tint = true,
                        shift = util.by_pixel(0 * spidertron_scale, 3.5 * spidertron_scale)
                    }
                }
            }
        },
        shadow_base_animation = {
            filename = me.image_base .. "torso/spidertron-body-bottom-shadow.png",
            width = 72,
            height = 48,
            line_length = 1,
            direction_count = 1,
            scale = spidertron_scale,
            draw_as_shadow = true,
            shift = util.by_pixel(-1 * spidertron_scale, -1 * spidertron_scale),
            hr_version = {
                filename = me.image_base .. "torso/hr-spidertron-body-bottom-shadow.png",
                width = 144,
                height = 96,
                line_length = 1,
                direction_count = 1,
                scale = 0.5 * spidertron_scale,
                draw_as_shadow = true,
                shift = util.by_pixel(-1 * spidertron_scale, -1 * spidertron_scale)
            }
        },
        animation = {
            layers = {
                {
                    filename = me.image_base .. "torso/spidertron-body.png",
                    width = 66,
                    height = 70,
                    line_length = 8,
                    direction_count = 64,
                    scale = spidertron_scale,
                    shift = util.by_pixel(0 * spidertron_scale, -19 * spidertron_scale),
                    hr_version = {
                        filename = me.image_base .. "torso/hr-spidertron-body.png",
                        width = 132,
                        height = 138,
                        line_length = 8,
                        direction_count = 64,
                        scale = 0.5 * spidertron_scale,
                        shift = util.by_pixel(0 * spidertron_scale, -19 * spidertron_scale)
                    }
                },
                {
                    filename = me.image_base .. "torso/spidertron-body-mask.png",
                    width = 66,
                    height = 50,
                    line_length = 8,
                    direction_count = 64,
                    scale = spidertron_scale,
                    apply_runtime_tint = true,
                    shift = util.by_pixel(0 * spidertron_scale, -14 * spidertron_scale),
                    hr_version = {
                        filename = me.image_base .. "torso/hr-spidertron-body-mask.png",
                        width = 130,
                        height = 100,
                        line_length = 8,
                        direction_count = 64,
                        scale = 0.5 * spidertron_scale,
                        apply_runtime_tint = true,
                        shift = util.by_pixel(0 * spidertron_scale, -14 * spidertron_scale)
                    }
                }
            }
        },
        shadow_animation = {
            filename = me.image_base .. "torso/spidertron-body-shadow.png",
            width = 96,
            height = 48,
            line_length = 8,
            direction_count = 64,
            scale = spidertron_scale,
            draw_as_shadow = true,
            shift = util.by_pixel(26 * spidertron_scale, 1 * spidertron_scale),
            hr_version = {
                filename = me.image_base .. "torso/hr-spidertron-body-shadow.png",
                width = 192,
                height = 94,
                line_length = 8,
                direction_count = 64,
                scale = 0.5 * spidertron_scale,
                draw_as_shadow = true,
                shift = util.by_pixel(26 * spidertron_scale, 0.5 * spidertron_scale)
            }
        },
        water_reflection = {
            pictures = {
                filename = me.image_base .. "torso/spidertron-body-water-reflection.png",
                width = 448,
                height = 448,
                variation_count = 1,
                scale = 0.5 * spidertron_scale,
                shift = util.by_pixel(0 * spidertron_scale, 0 * spidertron_scale)
            }
        },
        light = {
            {
                minimum_darkness = 0.3,
                intensity = 0.4,
                size = 25 * spidertron_scale,
                color = {r = 1.0, g = 1.0, b = 1.0}
            },
            create_spidertron_light_cone(0, 1, 1, -1),
            create_spidertron_light_cone(-0.05, 0.7, 0.7, 2.5),
            create_spidertron_light_cone(0.04, 0.5, 0.45, 5.5),
            create_spidertron_light_cone(0.06, 0.6, 0.35, 6.5)
        },
        light_positions = require("__base__/prototypes/entity/spidertron-light-positions"),
        eye_light = {intensity = 1, size = 1, color = {r = 1.0, g = 1.0, b = 1.0}},
        -- {r=1.0, g=0.0, b=0.0}},
        render_layer = "wires-above",
        base_render_layer = "higher-object-above",
        autopilot_destination_on_map_visualisation = {
            filename = "__core__/graphics/spidertron-target-map-visualization.png",
            priority = "extra-high-no-scale",
            scale = 0.5,
            flags = {"icon"},
            width = 64,
            height = 64,
            line_length = 8,
            frame_count = 24,
            animation_speed = 0.5,
            run_mode = "backward",
            apply_runtime_tint = true
        },
        autopilot_destination_queue_on_map_visualisation = {
            filename = "__core__/graphics/spidertron-target-map-visualization.png",
            priority = "extra-high-no-scale",
            scale = 0.5,
            flags = {"icon"},
            width = 64,
            height = 64,
            line_length = 8,
            frame_count = 24,
            animation_speed = 0.5,
            run_mode = "backward",
            apply_runtime_tint = true
        },
        autopilot_path_visualisation_on_map_line_width = 2, -- in pixels
        autopilot_path_visualisation_line_width = 1 / 8, -- in tiles
        autopilot_destination_visualisation_render_layer = "object",
        autopilot_destination_visualisation = {
            filename = "__core__/graphics/spidertron-target-map-visualization.png",
            priority = "extra-high-no-scale",
            scale = 0.5,
            flags = {"icon"},
            width = 64,
            height = 64,
            line_length = 8,
            frame_count = 24,
            animation_speed = 0.5,
            run_mode = "backward",
            apply_runtime_tint = true
        },
        autopilot_destination_queue_visualisation = {
            filename = "__core__/graphics/spidertron-target-map-visualization.png",
            priority = "extra-high-no-scale",
            scale = 0.5,
            flags = {"icon"},
            width = 64,
            height = 64,
            line_length = 8,
            frame_count = 24,
            animation_speed = 0.5,
            run_mode = "backward",
            apply_runtime_tint = true
        }
    }
end

function me.create_spidertron_leg_graphics_set(spidertron_scale, leg_index)
    local function get_leg_properties(part_name, suffix)
        return me.get_leg_graphics_properties(spidertron_scale, leg_index)[part_name .. "_" .. suffix] or me.get_leg_graphics_properties(spidertron_scale, leg_index)[part_name]
    end

    return {
        upper_part = create_leg_part_graphics(
            spidertron_scale,
            leg_index,
            get_part("leg_upper_part_graphics_definitions"),
            me.get_leg_graphics_properties(spidertron_scale, leg_index).upper_part
        ),
        lower_part = create_leg_part_graphics(
            spidertron_scale,
            leg_index,
            get_part("leg_lower_part_graphics_definitions"),
            me.get_leg_graphics_properties(spidertron_scale, leg_index).lower_part
        ),
        upper_part_shadow = create_leg_part_shadow_graphics(
            spidertron_scale,
            leg_index,
            get_part("leg_upper_part_graphics_definitions"),
            get_leg_properties("upper_part", "shadow")
        ),
        lower_part_shadow = create_leg_part_shadow_graphics(
            spidertron_scale,
            leg_index,
            get_part("leg_lower_part_graphics_definitions"),
            get_leg_properties("lower_part", "shadow")
        ),
        upper_part_water_reflection = create_leg_part_water_reflection_graphics(
            spidertron_scale,
            leg_index,
            get_part("leg_upper_part_graphics_definitions"),
            get_leg_properties("upper_part", "water_reflection")
        ),
        lower_part_water_reflection = create_leg_part_water_reflection_graphics(
            spidertron_scale,
            leg_index,
            get_part("leg_lower_part_graphics_definitions"),
            get_leg_properties("lower_part", "water_reflection")
        ),
        joint = {
            layers = {
                create_leg_sprite_layer_definition(spidertron_scale, leg_index, 1, {}, get_part("leg_joint_graphics_definitions")),
                create_leg_sprite_layer_definition(spidertron_scale, leg_index, 3, {apply_runtime_tint = true}, get_part("leg_joint_graphics_definitions"))
            }
        },
        joint_shadow = create_leg_sprite_layer_definition(spidertron_scale, leg_index, 2, {draw_as_shadow = true}, get_part("leg_joint_graphics_definitions")),
        joint_turn_offset = me.get_spidertron_leg_joint_rotation_offsets(spidertron_scale, leg_index)
    }
end

return me
