function create_copy_spidertron(spidertron_name)
    local constructron_name = "constructron-" .. spidertron_name
    local constructron = table.deepcopy(data.raw["spider-vehicle"][spidertron_name])
    constructron.name = constructron_name
    constructron.minable.result = constructron_name

    local constructron_item = {
        name = constructron_name,
        order = "b[personal-transport]-c[spidertron]-a["..constructron_name.."]b",
        place_result = constructron_name,
        stack_size = 1,
        subgroup = "transport",
        type = "item-with-entity-data"
    }

    if constructron.icons then
        table.insert(constructron.icons, 1, {
            icon = "__Constructron-Continued__/graphics/icon_texture.png",
            icon_size = 256,
            scale = 0.25
        })
    else
        constructron.icons = {
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
    constructron_item.icons = constructron.icons

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

    return constructron_name, {constructron, constructron_item, constructron_recipe}
end