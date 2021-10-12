local constructron = table.deepcopy(data.raw["spider-vehicle"]["spidertron"])
constructron.name = "constructron"

local constructron_item = table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
constructron_item.name = "constructron"
constructron_item.place_result = "constructron"
constructron_item.order = constructron_item.order .. "b"

constructron_recipe = table.deepcopy(data.raw["recipe"]["spidertron"])
constructron_recipe.name = "constructron"
constructron_recipe.result = "constructron"

data:extend({constructron, constructron_item, constructron_recipe})

table.insert(data.raw["technology"]["spidertron"].effects, {
    type = "unlock-recipe",
    recipe = "constructron"
})
