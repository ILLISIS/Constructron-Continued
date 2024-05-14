data:extend({
    {
        type = "bool-setting",
        name = "constructron-easy-recipe-toggle",
        setting_type = "startup",
        default_value = true
    }, {
        type = "int-setting",
        name = "desired_robot_count",
        order = "10",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 0,
        maximum_value = 10000
    }, {
        type = "string-setting",
        name = "desired_robot_name",
        order = "20",
        setting_type = "runtime-global",
        default_value = "construction-robot"
    }, {
        type = "int-setting",
        name = "entities_per_second",
        order = "30",
        setting_type = "runtime-global",
        default_value = 1000,
        minimum_value = 100,
        maximum_value = 100000
    }, {
        type = "int-setting",
        name = "job-start-delay",
        order = "40",
        setting_type = "runtime-global",
        default_value = 5,
        minimum_value = 0,
        maximum_value = 600
    }, {
        type = "bool-setting",
        name = "construct_jobs",
        order = "50",
        setting_type = "runtime-global",
        default_value = true
    }, {
        type = "bool-setting",
        name = "rebuild_jobs",
        order = "60",
        setting_type = "runtime-global",
        default_value = true
    },{
        type = "bool-setting",
        name = "deconstruct_jobs",
        order = "70",
        setting_type = "runtime-global",
        default_value = true
    }, {
        type = "bool-setting",
        name = "upgrade_jobs",
        order = "80",
        setting_type = "runtime-global",
        default_value = true
    }, {
        type = "bool-setting",
        name = "destroy_jobs",
        order = "90",
        setting_type = "runtime-global",
        default_value = false
    }, {
        type = "string-setting",
        name = "ammo_name",
        order = "91",
        setting_type = "runtime-global",
        default_value = "rocket"
    }, {
        type = "int-setting",
        name = "ammo_count",
        setting_type = "runtime-global",
        order = "92",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 100000
    }, {
        type = "bool-setting",
        name = "repair_jobs",
        order = "b100",
        setting_type = "runtime-global",
        default_value = false
    }, {
        type = "int-setting",
        name = "repair_percent",
        setting_type = "runtime-global",
        order = "b101",
        default_value = 75,
        minimum_value = 1,
        maximum_value = 100
    },  {
        type = "bool-setting",
        name = "enable_rocket_powered_constructron",
        setting_type = "startup",
        default_value = false
    }, {
        type = "bool-setting",
        name = "horde_mode",
        order = "b110",
        setting_type = "runtime-global",
        default_value = false
    }, {
        type = "bool-setting",
        name = "constructron-debug-enabled",
        setting_type = "runtime-global",
        order = "b120",
        default_value = false
    }
})

if mods["nullius"] then
    data.raw["string-setting"]["desired_robot_name"].default_value = "nullius-construction-bot-1"
end
