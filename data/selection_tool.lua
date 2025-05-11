data:extend(
    {
        {
            type = "selection-tool",
            name = "ctron-selection-tool",
            icons = {{ icon = "__Constructron-Continued__/graphics/icon_texture.png", icon_size = 128, mipmap_count = 2 }},
            always_include_tiles = true,
            skip_fog_of_war = false,
            stack_size = 1,
            flags = { "only-in-cursor", "not-stackable", "spawnable" },

            -- left click
            select = {
                border_color = { r = 0, g = 0, b = 0.5 }, -- blue
                cursor_box_type = "entity",
                mode = { "entity-ghost", "tile-ghost" }
            },

            -- shift left click
            alt_select = {
                border_color = { r = 1, g = 1, b = 1 },
                cursor_box_type = "entity",
                mode = { "controllable" },
                entity_filters = { "constructron" },
                entity_filter_mode = "whitelist",
            },

            -- control shift left click
            super_forced_select = {
                border_color = { r = 1, g = 1, b = 1 },
                cursor_box_type = "entity",
                mode = { "nothing" }
            },

            -- right click
            reverse_select = {
                border_color = { r = 1 }, -- red
                cursor_box_type = "entity",
                mode = { "deconstruct", "items", "trees" }
            },

            -- shift right click
            alt_reverse_select = {
                border_color = { r = 0, g = 0, b = 0 }, -- black
                cursor_box_type = "entity",
                mode = { "enemy" },
                entity_type_filters = { "unit-spawner", "turret" },
            },
        }
    }
)