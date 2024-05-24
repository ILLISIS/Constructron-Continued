data:extend({
    {
        type = "shortcut",
        name = "ctron-get-selection-tool",
        icon = {
            filename = "__Constructron-Continued__/graphics/icon_texture.png",
            size = 128,
            mipmap_count = 2,
            scale = 4,
            flags = { "gui-icon" }
        },
        -- disabled_icon = {
        --     filename = "__Constructron-Continued__/graphics/icon_texture.png",
        --     size = 64,
        --     mipmap_count = 2,
        --     flags = { "gui-icon" }
        -- },
        -- small_icon = {
        --     filename = "__Constructron-Continued__/graphics/icon_texture.png",
        --     size = 64,
        --     mipmap_count = 2,
        --     flags = { "gui-icon" }
        --     },
        -- disabled_small_icon = {
        --     filename = "__Constructron-Continued__/graphics/icon_texture.png",
        --     size = 64,
        --     mipmap_count = 2,
        --     flags = { "gui-icon" }
        -- },
        action = "lua",
        associated_control_input = "ctron-get-selection-tool"
    }
})