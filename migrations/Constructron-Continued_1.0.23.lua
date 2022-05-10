-- Rocket powered constructions were missing from on_built_event in v1.0.22
-- entity destroyed was not changing the entities _count.
local cmd = require("__Constructron-Continued__.script.command_functions")
cmd.reload_entities()
game.print('Constructron-Continued: v1.0.23 migration complete!')