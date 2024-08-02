local cmd = require("script/command_functions")

local init_repair_tool_name
global.repair_tool_name = {}
if game.item_prototypes["repair-pack"] then
    init_repair_tool_name = "repair-pack"
else
    local valid_repair_tools = game.get_filtered_item_prototypes{{filter = "type", type = "repair-tool"}}
    local valid_repair_tool_name = pairs(valid_repair_tools)(nil,nil)
    init_repair_tool_name = valid_repair_tool_name
end

for _, surface in pairs(game.surfaces) do
    local surface_index = surface.index
    global.repair_tool_name[surface_index] = init_repair_tool_name
end

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v1.1.21 migration complete!')