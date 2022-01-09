data:extend({
	{
		type = "int-setting",
		name = "max-worker-per-job",
		setting_type = "runtime-global",
		default_value = 4,
		minimum_value = 1,
        maximum_value = 10,
	},
	{
		type = "bool-setting",
		name = "constructron-debug-enabled",
		setting_type = "runtime-global",
		order = "a1",
		default_value = true,
	},
})
