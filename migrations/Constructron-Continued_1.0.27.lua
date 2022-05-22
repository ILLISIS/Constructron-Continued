-- Fixes for lastpos crash
for index, job in pairs(global.job_bundles) do
    for k, action in pairs(job) do
        if action.action == 'go_to_position' then
            action.lastpos = {}
        end
    end
end
game.print('Constructron-Continued: v1.0.27 migration complete!')