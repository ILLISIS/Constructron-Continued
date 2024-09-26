
-- decommission
global.queue_proc_trigger = nil
global.job_proc_trigger = nil
global.construction_tick = nil
global.deconstruction_tick = nil
global.upgrade_tick = nil
global.repair_tick = nil
global.destroy_tick = nil


-- add last_update_tick to all chunks

local job_types = {
    ["deconstruction"] = 0,
    ["construction"] = 0,
    ["upgrade"] = 0,
    ["repair"] = 0,
    ["destroy"] = 0
}

for job_type, _ in pairs(job_types) do
    for surface_index, _ in pairs(global.managed_surfaces) do
        for _, chunk in pairs(global[job_type .. '_queue'][surface_index]) do
            chunk.last_update_tick = game.tick
        end
    end
end

-------------------------------------------------------------------------------
game.print('Constructron-Continued: v1.1.29 migration complete!')