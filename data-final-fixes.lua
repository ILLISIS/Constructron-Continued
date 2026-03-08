require("data/roboports")
require("data/constructron_pathing_proxy")

-- Custom Constructron Logic (Supports comma-separated list)
local custom_bases_string = settings.startup["custom-constructron-base"].value

if custom_bases_string and custom_bases_string ~= "" then
    -- Split by comma and loop
    for custom_base_name in string.gmatch(custom_bases_string, '([^,]+)') do
        custom_base_name = custom_base_name:match("^%s*(.-)%s*$") -- Trim extra whitespace
        
        if custom_base_name and custom_base_name ~= "" then
            local base_entity = data.raw["spider-vehicle"][custom_base_name]
            
            if base_entity then
                local custom_ctron_name = custom_base_name .. "-constructron"
                
                -- Dynamic Localised Name: "{Original Name} (Constructron)"
                local ctron_localised_name = {"", {"entity-name." .. custom_base_name}, " (Constructron)"}
                
                -- Copy Entity
                local new_entity = table.deepcopy(base_entity)
                new_entity.name = custom_ctron_name
                new_entity.minable.result = custom_ctron_name
                new_entity.localised_name = ctron_localised_name
                
                data:extend({new_entity})
                
                -- Copy Item
                local base_item = data.raw["item-with-entity-data"][custom_base_name] or data.raw["item"][custom_base_name]
                if base_item then
                    local new_item = table.deepcopy(base_item)
                    new_item.name = custom_ctron_name
                    new_item.place_result = custom_ctron_name
                    new_item.localised_name = ctron_localised_name
                    data:extend({new_item})
                    
                    -- Recipe (Create a recipe to turn the base vehicle into the constructron variant)
                    local base_recipe = data.raw["recipe"][custom_base_name]
                    if base_recipe then
                        local new_recipe = {
                            type = "recipe",
                            name = custom_ctron_name,
                            localised_name = ctron_localised_name,
                            enabled = base_recipe.enabled,
                            ingredients = {
                                {type = "item", name = custom_base_name, amount = 1}
                            },
                            results = {
                                {type = "item", name = custom_ctron_name, amount = 1}
                            },
                            energy = 1
                        }
                        data:extend({new_recipe})
                        
                        -- Add to technology if base recipe is unlocked via research
                        for _, tech in pairs(data.raw["technology"]) do
                            if tech.effects then
                                for _, effect in pairs(tech.effects) do
                                    if effect.type == "unlock-recipe" and effect.recipe == custom_base_name then
                                        table.insert(tech.effects, {type = "unlock-recipe", recipe = custom_ctron_name})
                                    end
                                end
                            end
                        end
                    end
                end

                -- Add to Selection Tool Filters so Shift+Click works
                local selection_tool = data.raw["selection-tool"]["ctron-selection-tool"]
                if selection_tool and selection_tool.alt_select and selection_tool.alt_select.entity_filters then
                    table.insert(selection_tool.alt_select.entity_filters, custom_ctron_name)
                end
            else
                log("Constructron-Continued: Custom base entity '" .. custom_base_name .. "' not found. Could not generate custom constructron.")
            end
        end
    end
end