--  service_station images derived from:
--    https://github.com/nEbul4/Factorio_Roboport_mk2/
--    https://github.com/kirazy/classic-beacon/

local util = require('util')

-------------------------------------------------------------------------------
-- Entity
-------------------------------------------------------------------------------

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
    layer.scale = 0.5
  end
end
-- Beacon Antenna
local shft_1 = util.by_pixel(-1, -55)
local shft_2 = util.by_pixel(100.5, 15.5)
service_station.base_animation = {
    layers = { -- Base
    {
        filename = "__Constructron-Continued__/graphics/entity/antenna.png",
        width = 108,
        height = 100,
        scale = 0.5,
        line_length = 8,
        frame_count = 32,
        animation_speed = 0.5,
        shift = util.by_pixel(-17, -77)
    }, -- Shadow
    {
        filename = "__Constructron-Continued__/graphics/entity/antenna-shadow.png",
        width = 126,
        height = 98,
        scale = 0.5,
        line_length = 8,
        frame_count = 32,
        animation_speed = 0.5,
        shift = util.by_pixel(91, 0),
        draw_as_shadow = true
    }}
}

-------------------------------------------------------------------------------
-- Item
-------------------------------------------------------------------------------

local service_station_item = {
  icons = {
    {
      icon = "__Constructron-Continued__/graphics/icon_texture.png",
      icon_size = 256,
      scale = 0.12
    },
    {
      icon = "__base__/graphics/icons/roboport.png",
      icon_size = 64,
      icon_mipmaps = 4,
      scale = 0.35
    }
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
    ingredients = {
      {type = "item", name = "roboport", amount = 1}
    },
    results = {
      {type = "item", name = "service_station", amount = 1}
    },
    energy = 1
  }

-------------------------------------------------------------------------------
-- Technology
-------------------------------------------------------------------------------

table.insert(
	data.raw["technology"]["spidertron"].effects,{
		type = "unlock-recipe",
		recipe="service_station"
	}
)

-------------------------------------------------------------------------------
-- Extend
-------------------------------------------------------------------------------

data:extend({service_station, service_station_item, service_station_recipe})