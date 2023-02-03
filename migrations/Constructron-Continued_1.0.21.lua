-- global.allowed_items = {}

global.construction_job_toggle = settings.global["construct_jobs"].value
global.rebuild_job_toggle = settings.global["rebuild_jobs"].value
global.deconstruction_job_toggle = settings.global["deconstruct_jobs"].value
-- global.ground_decon_job_toggle = settings.global["decon_ground_items"].value
global.upgrade_job_toggle = settings.global["upgrade_jobs"].value
global.repair_job_toggle = settings.global["repair_jobs"].value
global.debug_toggle = settings.global["constructron-debug-enabled"].value
-- global.landfill_job_toggle = settings.global["allow_landfill"].value
global.job_start_delay = (settings.global["job-start-delay"].value * 60)
global.desired_robot_count = settings.global["desired_robot_count"].value
global.desired_robot_name = settings.global["desired_robot_name"].value
-- global.max_worker_per_job = settings.global['max-worker-per-job'].value
-- global.construction_mat_alert = (settings.global["construction_mat_alert"].value * 60) -- removed in 1.0.65
-- global.max_jobtime = (settings.global["max-jobtime-per-job"].value * 60 * 60) -- removed in 1.0.65