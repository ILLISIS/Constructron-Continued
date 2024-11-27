-- set landfill type on existing jobs
for _, job in pairs(storage.jobs) do
    if job.landfill_job then
        job.landfill_type = "landfill"
    end
end


-------------------------------------------------------------------------------

game.print('Constructron-Continued: v2.0.14 migration complete!')