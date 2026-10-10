require("data/roboports")
require("data/constructron_pathing_proxy")

-- Remove constructron_pathing_layer from Universal Edges' barriers (v1's ue_world_barrier, v2's ue-barrier) so
-- Constructron robots can path near world edges without being blocked by the barrier entities.
if mods["universal_edges"] then
	for _, name in pairs({"ue_world_barrier", "ue-barrier"}) do
		local barrier = data.raw["simple-entity"][name]
		if barrier and barrier.collision_mask and barrier.collision_mask.layers then
			barrier.collision_mask.layers["constructron_pathing_layer"] = nil
		end
	end
end