-- local collision_mask_util_extended = require("data/collision-mask-util-extended")

data:extend(
  {
    {
      type = "collision-layer",
      name = "constructron_pathing_layer",
    }
  }
)
local selected_mask = "constructron_pathing_layer"

local types = {
  "arrow",
  "artillery-flare",
  "artillery-projectile",
  "beam",
  "character-corpse",
  "cliff",
  "corpse",
  "rail-remnants",
  "deconstructible-tile-proxy",
  -- "particle",
  -- "leaf-particle",
  "accumulator",
  "artillery-turret",
  "beacon",
  "boiler",
  "burner-generator",
  "character",
  "arithmetic-combinator",
  "decider-combinator",
  "constant-combinator",
  "container",
  "logistic-container",
  "infinity-container",
  "assembling-machine",
  "rocket-silo",
  "furnace",
  "electric-energy-interface",
  "electric-pole",
  "unit-spawner",
  "combat-robot",
  "construction-robot",
  "logistic-robot",
  "gate",
  "generator",
  "heat-interface",
  "heat-pipe",
  "inserter",
  "lab",
  "lamp",
  "land-mine",
  "linked-container",
  "market",
  "mining-drill",
  "offshore-pump",
  "pipe",
  "infinity-pipe",
  "pipe-to-ground",
  -- "player-port",
  "power-switch",
  "programmable-speaker",
  "pump",
  "radar",
  -- "curved-rail",
  "straight-rail",
  "rail-chain-signal",
  "rail-signal",
  "reactor",
  "roboport",
  "simple-entity-with-owner",
  "simple-entity-with-force",
  "solar-panel",
  "storage-tank",
  "train-stop",
  "linked-belt",
  "loader-1x1",
  "loader",
  "splitter",
  "transport-belt",
  "underground-belt",
  "turret",
  "ammo-turret",
  "electric-turret",
  "fluid-turret",
  "unit",
  "car",
  "artillery-wagon",
  "cargo-wagon",
  "fluid-wagon",
  "locomotive",
  "spider-vehicle",
  "wall",
  "fish",
  "simple-entity",
  "spider-leg",
  "tree",
  "explosion",
  -- "flame-thrower-explosion",
  "fire",
  "stream",
  -- "flying-text",
  "highlight-box",
  "item-entity",
  "item-request-proxy",
  "particle-source",
  "projectile",
  "resource",
  "rocket-silo-rocket",
  "rocket-silo-rocket-shadow",
  -- "smoke",
  "smoke-with-trigger",
  "speech-bubble",
  "sticker",
}

local pathing_collision_mask = {
  layers = {
    [selected_mask] = true
  },
  not_colliding_with_itself = true
}

local masks = {
  ["player"] = true,
  ["rail"] = true,
}

for _, type in pairs(types) do
  for name, prototype in pairs(data.raw[type]) do
    if prototype.collision_box and prototype.collision_mask then
      local collision_box = prototype.collision_box
      local width = collision_box[2][1] - collision_box[1][1]
      local height = collision_box[2][2] - collision_box[1][2]
      -- Check if entity is larger than 7x7 tiles
      if (width>7 and height>4) or (height>7 and width>4) then
        -- log("Entity '" .. name .. "' is larger than 7x7 tiles. Size: " .. width .. "x" .. height)
        local add = false
        for _, mask in pairs(prototype.collision_mask.layers) do
          if masks[mask] ~= nil then
            add = true
          end
        end
        if add then
          prototype.collision_mask.layers[selected_mask] = true
        end
      end
    -- else
      -- log ("Entity '" .. name .. "' has no collision_box or collision_mask")
    end
  end
end

for name, prototype in pairs(data.raw["tile"]) do
  if prototype.collision_mask then
    local add = false
    for mask, _ in pairs(prototype.collision_mask.layers) do
      if masks[mask] ~= nil then
        add = true
      end
    end
    if add then
      prototype.collision_mask.layers[selected_mask] = true
    end
  end
end

local template_entity = {
  type = "simple-entity",
  icon = "__core__/graphics/empty.png",
  icon_size = 1,
  icon_mipmaps = 0,
  flags = {"placeable-neutral", "not-on-map"},
  order = "z",
  max_health = 1,
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


for _, size in pairs({96, 64, 32, 16, 12, 10, 8, 6, 5, 4, 2, 1}) do
  local proxy_entity = table.deepcopy(template_entity)
  proxy_entity.collision_box = {{-size / 2, -size / 2}, {size / 2, size / 2}}
  proxy_entity.selection_box = {{-size / 2, -size / 2}, {size / 2, size / 2}}
  proxy_entity.name = "constructron_pathing_proxy_" .. size

  data:extend({proxy_entity})
end
