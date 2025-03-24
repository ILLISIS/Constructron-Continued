local job_types = {
    ["deconstruction"] = true,
    ["construction"] = true,
    ["upgrade"] = true,
    ["repair"] = true,
    ["destroy"] = true
}

for job_type, job_class in pairs(job_types) do
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        for _, chunk in pairs(storage[job_type .. '_queue'][surface_index]) do
            if chunk.surface then
                chunk.surface_index = chunk.surface
                chunk.surface = nil
            end
        end
    end
end

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v2.0.21 migration complete!')