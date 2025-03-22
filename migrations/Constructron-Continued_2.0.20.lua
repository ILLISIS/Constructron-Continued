storage.entity_proc_trigger = nil
storage.construction_entities = nil
storage.deconstruction_entities = nil
storage.upgrade_entities = nil
storage.repair_entities = nil
storage.destroy_entities = nil
storage.entities_per_second = nil

storage.zone_restriction_job_toggle = {}
for _, surface in pairs(game.surfaces) do
    local surface_index = surface.index
    storage.zone_restriction_job_toggle[surface_index] = false
end

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v2.0.20 migration complete!')