local utility_func = require("script/utility_functions")

storage.max_pathfinder_iterations = 200

-- To fix any possible available count issues

-- for each surface
for _, surface in pairs(game.surfaces) do
    -- set the count to 0
    storage.available_ctron_count[surface.index] = 0
    for _, constructron in pairs(storage.constructrons) do
        -- check surface matches and constructron is not busy
        if (constructron.surface.index == surface.index) and not utility_func.get_constructron_status(constructron, "busy") then
            storage.available_ctron_count[surface.index] = storage.available_ctron_count[surface.index] + 1
        end
    end
end