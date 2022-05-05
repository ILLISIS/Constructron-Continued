data:extend({{
    type = "int-setting",
    name = "max-worker-per-job",
    setting_type = "runtime-global",
    default_value = 4,
    minimum_value = 1,
    maximum_value = 10
}, {
    type = "bool-setting",
    name = "constructron-debug-enabled",
    setting_type = "runtime-global",
    order = "a1",
    default_value = false
}, {
    type = "bool-setting",
    name = "constructron-easy-recipe-toggle",
    setting_type = "startup",
    default_value = true
}, {
    type = "int-setting",
    name = "max-jobtime-per-job",
    setting_type = "runtime-global",
    default_value = 2,
    minimum_value = 1,
    maximum_value = 10
}, {
    type = "int-setting",
    name = "job-start-delay",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 0,
    maximum_value = 600
}, {
    type = "int-setting",
    name = "desired_robot_count",
    setting_type = "runtime-global",
    default_value = 50,
    minimum_value = 0,
    maximum_value = 10000
}, {
    type = "string-setting",
    name = "desired_robot_name",
    setting_type = "runtime-global",
    default_value = "construction-robot"
}, {
    type = "bool-setting",
    name = "construct_jobs",
    order = "a1",
    setting_type = "runtime-global",
    default_value = true
}, {
    type = "bool-setting",
    name = "rebuild_jobs",
    order = "a2",
    setting_type = "runtime-global",
    default_value = true
},{
    type = "bool-setting",
    name = "deconstruct_jobs",
    order = "a3",
    setting_type = "runtime-global",
    default_value = true
}, {
    type = "bool-setting",
    name = "upgrade_jobs",
    order = "a4",
    setting_type = "runtime-global",
    default_value = true
}, {
    type = "bool-setting",
    name = "repair_jobs",
    order = "a5",
    setting_type = "runtime-global",
    default_value = false
}, {
    type = "int-setting",
    name = "repair_percent",
    setting_type = "runtime-global",
    order = "a6",
    default_value = 75,
    minimum_value = 1,
    maximum_value = 99
}, {
    type = "bool-setting",
    name = "allow_landfill",
    order = "a7",
    setting_type = "runtime-global",
    default_value = true
}, {
    type = "int-setting",
    name = "construction_mat_alert",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 0,
    maximum_value = 3600
}, {
    type = "int-setting",
    name = "entities_per_tick",
    setting_type = "runtime-global",
    default_value = 100,
    minimum_value = 100,
    maximum_value = 10000
}, {
    type = "bool-setting",
    name = "decon_ground_items",
    order = "a8",
    setting_type = "runtime-global",
    default_value = true
}, {
    type = "bool-setting",
    name = "pathfinder_cache_enabled",
    order = "a9",
    setting_type = "startup",
    default_value = true
}, {
    type = "bool-setting",
    name = "enable_rocket_powered_constructron",
    order = "a9",
    setting_type = "startup",
    default_value = false
}
})
