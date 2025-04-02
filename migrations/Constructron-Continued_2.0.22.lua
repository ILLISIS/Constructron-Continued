--for each job, set the robot_inactivity_counter to 0
for _, job in pairs(storage.jobs) do
    job.robot_inactivity_counter = 0
end

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v2.0.22 migration complete!')