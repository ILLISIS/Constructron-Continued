for job_index, job in pairs(storage.jobs) do
    if job.job_type == "destroy" then
        if job.worker and job.worker.valid then
            if job.worker.prototype.indexed_guns[1] then
                job.gun_range = job.worker.prototype.indexed_guns[1].attack_parameters.range
            end
        end
        job.safe_positions = {}
        job.minion_jobs = {}
        job.considered_spawners = {}
        job.status = "starting"
    end
end

storage.global_threat_modifier = 1.6
local research_handlers = {
    ["stronger-explosives-3"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.1)
    end,
    ["stronger-explosives-4"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.1)
    end,
    ["stronger-explosives-5"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.1)
    end,
    ["stronger-explosives-6"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.1)
    end,
    ["weapon-shooting-speed-3"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.2)
    end,
    ["weapon-shooting-speed-4"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.2)
    end,
    ["weapon-shooting-speed-5"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.2)
    end,
    ["weapon-shooting-speed-6"] = function()
        storage.global_threat_modifier = math.max(0.4, storage.global_threat_modifier - 0.2)
    end,
    ["spidertron"] = function()
        game.print("Welcome to [item=constructron]! Please see the games tips and tricks for more information about Constructrons use!")
    end,
}

for research_name, handler in pairs(research_handlers) do
    if game.forces.player.technologies[research_name] and game.forces.player.technologies[research_name].researched then
        handler()
        game.print("handler activated, threat modifier is now: " .. storage.global_threat_modifier)
    end
end

storage.destroy_min_cluster_size = {}
storage.atomic_ammo_name = {}
storage.atomic_ammo_count = {}
storage.minion_count = {}

local init_atomic_name
if prototypes.item["atomic-bomb"] then
    init_atomic_name = { name = "atomic-bomb", quality = "normal" }
else
    -- get atomic ammo prototypes
    local atomic_ammo_prototypes = prototypes.get_item_filtered{{filter = "type", type = "ammo"}} -- TODO: check if can be filtered further in future API versions.
    -- iterate through atomic ammo prototypes to find atomic ammo
    for _, ammo in pairs(atomic_ammo_prototypes) do
        if ammo.ammo_category.name == "rocket" then -- check if this is atomic type ammo
            init_atomic_name = { name = ammo.name, quality = "normal" } -- set the variable to be used in the surface loop
            break
        end
    end
end

for _, surface in pairs(game.surfaces) do
    storage.destroy_min_cluster_size[surface.index] = storage.destroy_min_cluster_size[surface.index] or 8
    storage.atomic_ammo_name[surface.index] = storage.atomic_ammo_name[surface.index] or init_atomic_name
    storage.atomic_ammo_count[surface.index] = storage.atomic_ammo_count[surface.index] or 0
    storage.minion_count[surface.index] = storage.minion_count[surface.index] or 1
end

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v2.0.32 migration complete!')
game.print('Please report any issues via discord! https://discord.gg/m9TDSsH3u2')