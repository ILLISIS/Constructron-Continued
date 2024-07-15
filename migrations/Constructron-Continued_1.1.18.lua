local cmd = require("script/command_functions")

cmd.reset_settings()

global.available_ctron_count = global.available_ctron_count or {}
for _, surface in pairs(game.surfaces) do
    local count = 0
    for _, constructron in pairs(global.constructron_statuses) do
        if not (constructron.busy == true) then
            count = count + 1
        end
    end
    global.available_ctron_count[surface.index] = count
end

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v1.1.18 migration complete!')
game.print('Due to major internal changes, all settings have been reset.')
game.print('This version implements a user interface for oversight and control of Constructrons and jobs.')
game.print('Open the GUI with SHIFT + C + C')