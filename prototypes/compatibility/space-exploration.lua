if not mods["space-exploration"] then return end

local collision_util = require("__space-exploration__/collision-mask-util-extended/data/collision-mask-util-extended")
local data_util = require("__space-exploration__/data_util")

local rocketpowered_enabled = settings.startup["enable_rocket_powered_constructron"].value

-- [update collision mask for pathing proxy]
local additional_proxy_layers = {}
table.insert(additional_proxy_layers, collision_util.get_named_collision_mask("moving-tile"))

if not rocketpowered_enabled then
  table.insert(additional_proxy_layers, collision_util.get_named_collision_mask("empty-space-tile"))
end

-- check each simple-entity if its a pathing proxy and add additional layers to its collision mask
for _, entity in pairs(data.raw["simple-entity"]) do
  if entity.name:find("constructron_pathing_proxy_") then
    for _, layer in pairs(additional_proxy_layers) do
      table.insert(entity.collision_mask, layer)
    end
  end
end


-- [update collision mask for constructron]
local constructron = data.raw["spider-vehicle"]["constructron"]
local additional_ctron_layers = {}

-- removed becuase it caused despawns when constructrons built space ship tiles. (pathfinder still collides)
-- local spaceship_collision_layer = collision_util.get_named_collision_mask("moving-tile")
-- table.insert(additional_ctron_layers, spaceship_collision_layer)

if rocketpowered_enabled then
    --collide with all of "space"
    local collision_mask_space_tile = collision_util.get_named_collision_mask("space-tile")
    table.insert(additional_ctron_layers, collision_mask_space_tile)
else
    --collide with "empty space"
    local empty_space_collision_layer = collision_util.get_named_collision_mask("empty-space-tile")
    table.insert(additional_ctron_layers, empty_space_collision_layer)
end

-- add additional layers to constructron collision mask
for _, layer in pairs(additional_ctron_layers) do
  table.insert(constructron.collision_mask, layer)
end

-- check each spider leg if its a constructron leg by checking its name and add additional layers to its collision mask
local leg_prefix = constructron.name .. "_leg_"
for _, leg in pairs(data.raw["spider-leg"]) do
  if leg.name:find(leg_prefix) then
    for _, layer in pairs(additional_ctron_layers) do
      table.insert(leg.collision_mask, layer)
    end
  end
end

-- add 'Can not be placed on:' description to constructron
data_util.collision_description(constructron)

-- add rocket powered constructron
if rocketpowered_enabled then
    require("prototypes/constructron-rocket-powered")
end
