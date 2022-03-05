local constructron = table.deepcopy(data.raw["spider-vehicle"]["spidertron"])
constructron.name = "constructron"
constructron.minable = {hardness = 0.5, mining_time = 1, result = "constructron"}

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
    ingredients =
    {
        {"raw-fish", 1},
        {"rocket-control-unit", 16},
        {"low-density-structure", 150},
        {"effectivity-module-3", 2},
        {"rocket-launcher", 4},
        {"fusion-reactor-equipment", 2},
        {"exoskeleton-equipment", 4},
        {"radar", 2},
    },
    result = "constructron",
    result_count = 1,
    energy = 1
}

local constructron_easy_recipe = {
    type = "recipe",
    name = "constructron",
    enabled = false,
    ingredients =
    {
        {"spidertron", 1},
    },
    result = "constructron",
    result_count = 1,
    energy = 1
}

if settings.startup["constructron-easy-recipe-toggle"].value then
    data:extend({constructron, constructron_item, constructron_easy_recipe})
else
    data:extend({constructron, constructron_item, constructron_recipe})
end

table.insert(data.raw["technology"]["spidertron"].effects, {
    type = "unlock-recipe",
    recipe = "constructron"
})
