local me = {}

me.constructron_names = {"constructron"}

if not script.active_mods["space-spidertron"] and script.active_mods["space-exploration"] and settings.startup["enable_rocket_powered_constructron"].value then
    table.insert(me.constructron_names, "constructron-rocket-powered")
end

if script.active_mods["space-spidertron"] then
    table.insert(me.constructron_names, "constructron-ss-space-spidertron")
end

if script.active_mods["spidertron-extended"] then
    table.insert(me.constructron_names, "constructron-spidertronmk2")
    table.insert(me.constructron_names, "constructron-spidertronmk3")
end

me.is_valid_constructron = {}

for _,ctor_name in pairs(me.constructron_names) do
    me.is_valid_constructron[ctor_name] = true
end

me.if_flying_constructron = {
    ["constructron-rocket-powered"] = true,
    ["constructron-ss-space-spidertron"] = true,
}

return me