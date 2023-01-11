local constructron_remote = table.deepcopy(data.raw["spidertron-remote"]["spidertron-remote"])
constructron_remote.name = "constructron-remote"
constructron_remote.flags = {"only-in-cursor", "not-stackable", "hidden", "hide-from-bonus-gui", "hide-from-fuel-tooltip"}

data:extend({constructron_remote})
