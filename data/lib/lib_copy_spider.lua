function create_copy_spidertron(spidertron_name)
    local constructron_name = "constructron-" .. spidertron_name
    local constructron = table.deepcopy(data.raw["spider-vehicle"][spidertron_name])
    constructron.name = constructron_name
    constructron.collision_mask = {
        "water-tile",
        "colliding-with-tiles-only",
        "not-colliding-with-itself"
    }
    constructron.minable.result = constructron_name

    local constructron_item = {
        name = constructron_name,
        order = "b[personal-transport]-c[spidertron]-a[spider]b",
        place_result = constructron_name,
        stack_size = 1,
        subgroup = "transport",
        type = "item-with-entity-data"
    }

    if constructron.icons then
        local item_icons = constructron.icons
        table.insert(item_icons, 1, {
            icon = "__Constructron-Continued__/graphics/icon_texture.png",
            icon_size = 256,
            scale = 0.25
        })
        constructron_item.icons = item_icons
    else
        constructron_item.icons = {
            {
                icon = "__Constructron-Continued__/graphics/icon_texture.png",
                icon_size = 256,
                scale = 0.25
            },
            {
                icon = constructron.icon,
                icon_size = 64,
                icon_mipmaps = 4,
                scale = 1
            }
        }
    end

    local constructron_recipe = {
        type = "recipe",
        name = constructron_name,
        enabled = false,
        ingredients = {
            {spidertron_name, 1}
        },
        result = constructron_name,
        result_count = 1,
        energy = 1
    }

    -- Add the 'Cannot be placed on:' SE description
    if mods["space-exploration"] then
        constructron.localised_description = {""}
        local data_util = require("__space-exploration__/data_util")
        data_util.collision_description(constructron)
    end

    return constructron_name, {constructron, constructron_item, constructron_recipe}
end