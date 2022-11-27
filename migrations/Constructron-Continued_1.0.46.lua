-- Entities were not being registered prior to 1.0.45 when construction jobs were disabled
local cmd = require("script/command_functions")
cmd.reload_entities()
game.print('Constructron-Continued: v1.0.46 migration complete!')