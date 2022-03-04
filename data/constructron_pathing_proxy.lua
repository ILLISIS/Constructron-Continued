local collision_mask_util_extended = require("__Constructron-Continued__.data.collision-mask-util-extended")
local pathing_collision_mask = {
  "water-tile",
  "colliding-with-tiles-only",
  "not-colliding-with-itself"
}
if mods["space-exploration"] then
  local spaceship_collision_layer = collision_mask_util_extended.get_named_collision_mask("moving-tile")
  local empty_space_collision_layer = collision_mask_util_extended.get_named_collision_mask("empty-space-tile")
  table.insert(pathing_collision_mask, spaceship_collision_layer)
  table.insert(pathing_collision_mask, empty_space_collision_layer)
end

local constructron_pathing_dummy = {
  type = "simple-entity",
  name = "constructron_pathing_dummy",
  icon = "__core__/graphics/empty.png",
  icon_size = 1,
  icon_mipmaps = 0,
  flags = {"placeable-neutral", "not-on-map"},
  order = "z",
  max_health = 1,
  collision_box = {{-3, -3}, {3, 3}},
  selection_box = {{-3, -3}, {3, 3}},
  render_layer = "object",
  collision_mask = pathing_collision_mask,
  pictures = {
    {
      filename = "__core__/graphics/empty.png",
      width = 1,
      height = 1
    }
  }
}

local constructron_pathing_dummy_item = {
  type = "item",
  flags = {
    "hidden"
  },
  name = "constructron_pathing_dummy",
  icon = "__core__/graphics/empty.png",
  icon_size = 1,
  order = "z",
  place_result = "constructron_pathing_dummy",
  stack_size = 1
}
data:extend({constructron_pathing_dummy, constructron_pathing_dummy_item})
