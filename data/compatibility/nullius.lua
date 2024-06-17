if not mods["nullius"] then return end

local ctron_item = data.raw["item-with-entity-data"]["constructron"]
local station_item = data.raw["item"]["service_station"]
ctron_item.subgroup = "robot"
station_item.subgroup = "hangar-2"
ctron_item.order = "nullius-z" .. ctron_item.order
station_item.order = "nullius-z" .. station_item.order

local ctron_recipe = data.raw.recipe["constructron"]
local station_recipe = data.raw.recipe["service_station"]
ctron_recipe.category = "huge-crafting"
station_recipe.category = "large-crafting"
ctron_recipe.order = ctron_item.order
station_recipe.order = station_item.order

ctron_recipe.ingredients = {
    { "nullius-mecha", 1 }
}
station_recipe.ingredients = {
    { "nullius-hangar-3", 1 }
}

local tech = data.raw.technology["nullius-personal-transportation-4"]
table.insert(
    tech.effects,
    {
        type = "unlock-recipe",
        recipe = "constructron"
    }
)
table.insert(
    tech.effects,
    {
        type = "unlock-recipe",
        recipe = "service_station"
    }
)

local spider = data.raw["spider-vehicle"]["constructron"]
if spider then
    local grid_name = spider.equipment_grid
    if grid_name then
        local grid = data.raw["equipment-grid"][grid_name]
        if grid then
            table.insert(grid.equipment_categories, "cybernetic")
        end
    end
end