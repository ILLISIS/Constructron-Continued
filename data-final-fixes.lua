require("data/roboports")
require("data/constructron_pathing_proxy")

-- Remove constructron_pathing_layer from ue_world_barrier so Constructron robots
-- can path near world edges without being blocked by the barrier entities.
if mods["universal_edges"] then
	local barrier = data.raw["simple-entity"]["ue_world_barrier"]
	if barrier and barrier.collision_mask and barrier.collision_mask.layers then
		barrier.collision_mask.layers["constructron_pathing_layer"] = nil
	end
end