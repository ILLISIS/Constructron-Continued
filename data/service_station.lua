--  service_station images derived from:
--    https://github.com/nEbul4/Factorio_Roboport_mk2/
--    https://github.com/kirazy/classic-beacon/
local util = require('util')
local service_station = table.deepcopy(data.raw["roboport"]["roboport"])
service_station.name = "service_station"
service_station.minable = {
  hardness = 0.2,
  mining_time = 0.5,
  result = "service_station"
}
service_station.logistics_radius = 10
service_station.construction_radius = 0

for _, layer in pairs(service_station.base.layers) do
  if layer.filename == "__base__/graphics/entity/roboport/roboport-base.png" then
    layer.filename = "__Constructron-Continued__/graphics/entity/constructron-service-station.png"
    layer.width = 114
    layer.height = 139
    layer.shift = layer.hr_version.shift
    layer.hr_version.filename = "__Constructron-Continued__/graphics/entity/hr-constructron-service-station.png"
  end
end
-- Beacon Antenna
local shft_1 = util.by_pixel(-1, -55)
local shft_2 = util.by_pixel(100.5, 15.5)
service_station.base_animation = {
    layers = { -- Base
    {
        filename = "__Constructron-Continued__/graphics/entity/antenna.png",
        width = 54,
        height = 50,
        line_length = 8,
        frame_count = 32,
        animation_speed = 0.5,
        shift = {shft_1[1] - 0.5, shft_1[2] - 0.5}
    }, -- Shadow
    {
        filename = "__Constructron-Continued__/graphics/entity/antenna-shadow.png",
        width = 63,
        height = 49,
        line_length = 8,
        frame_count = 32,
        animation_speed = 0.5,
        shift = {shft_2[1] - 0.5, shft_2[2] - 0.5},
        draw_as_shadow = true
    }}
}

local service_station_item = {
  icons = {
    {
      icon = "__Constructron-Continued__/graphics/icon_texture.png",
      icon_size = 256,
      -- scale = 0.25
    },
    {
      icon = "__base__/graphics/icons/roboport.png",
      icon_size = 64,
      icon_mipmaps = 4,
      scale = 0.4
    }

    -- {
    --   icon = "__base__/graphics/icons/spidertron.png",
    --   icon_size = 64,
    --   icon_mipmaps = 4,
    --   scale = 0.6,
    --   shift = {-20, 20}
    -- }
  },
  name = "service_station",
  order = "c[signal]-a[roboport]b",
  place_result = "service_station",
  stack_size = 5,
  subgroup = "logistic-network",
  type = "item"
}

local service_station_recipe = {
    type = "recipe",
    name = "service_station",
    enabled = false,
    ingredients =
    {
      {"steel-plate", 45},
      {"iron-gear-wheel", 45},
      {"advanced-circuit", 45},
    },
    result = "service_station",
    result_count = 1,
    energy = 1
  }

local service_station_easy_recipe = {
    type = "recipe",
    name = "service_station",
    enabled = false,
    ingredients =
    {
      {"roboport", 1},
    },
    result = "service_station",
    result_count = 1,
    energy = 1
  }

if settings.startup["constructron-easy-recipe-toggle"].value then
  data:extend({service_station, service_station_item, service_station_easy_recipe})
else
  data:extend({service_station, service_station_item, service_station_recipe})
end


table.insert(data.raw["technology"]["spidertron"].effects,{type = "unlock-recipe", recipe="service_station"})
