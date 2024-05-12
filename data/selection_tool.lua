data:extend({
  {
    type = "selection-tool",
    name = "ctron-selection-tool",
    icons = {
    --   { icon = data_util.black_image, icon_size = 1, scale = 64 },
      { icon = "__Constructron-Continued__/graphics/icon_texture.png", icon_size = 32, mipmap_count = 2 }
    },

    selection_color = { r = 1, g = 0, b = 1 },
    selection_cursor_box_type = "entity",
    selection_mode = { "entity-ghost", "tile-ghost" },

    reverse_selection_color = { r = 1, g = 1 },
    reverse_selection_cursor_box_type = "entity",
    reverse_selection_mode = { "deconstruct", "items", "trees" },

    alt_selection_color = { r = 1 },
    alt_selection_cursor_box_type = "entity",
    alt_selection_mode = { "nothing" },

    alt_reverse_selection_color = { r = 1 },
    alt_reverse_selection_cursor_box_type = "entity",
    alt_reverse_selection_mode = { "is-military-target" },

    stack_size = 1,
    flags = { "hidden", "only-in-cursor", "not-stackable", "spawnable" }
  }
})