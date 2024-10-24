---@meta
-- DO NOT REQUIRE THIS FILE ANYWHERE! THIS IS ONLY FOR INTELLISENSE

-- [ALIASES]

---@alias Area BoundingBox

---@alias ItemCounts table<string, integer>

---@alias EntityQueue table<uint, table<string, Chunk>>

---@alias ConstructronStatus
---| "busy"

---@alias JobType
---| "deconstruct"
---| "construct"
---| "upgrade"
---| "repair"
---| "destroy"
---| "utility"
---| "logistic"

-- [CLASSES]

-- extends vanilla pathfinder request parameters
---@class LuaSurface.request_path_param
---@field unit LuaEntity?
---@field units LuaEntity[]
---@field request_tick uint?
---@field initial_target MapPosition?

---@class Chunk
---@field area Area
---@field key string
---@field surface uint
---@field last_update_tick uint
---@field minimum MapPosition
---@field maximum MapPosition
-- -@field position MapPosition
---@field merged boolean?
---@field required_items ItemCounts
---@field trash_items ItemCounts

---@class job
---@field job_class JobType?
---@field index uint
---@field landfill_job boolean?
---@field attempt uint
---@field path_active boolean?
---@field path_requestid uint
---@field robot_positions table
---@field worker LuaEntity

---@class RegisteredEntity
---@field name string
---@field surface uint

---@class UpgradeEntity
---@field entity LuaEntity
---@field target LuaEntityPrototype?

---@class Global
--- PATHFINDER
---@field pathfinder_requests table<uint, LuaSurface.request_path_param>
--- CUSTOM PATHFINDER
---@field custom_pathfinder_index uint
---@field custom_pathfinder_requests table<uint, table<any>?>
---@field mainland_chunks table<string, boolean>
--- MISC
---@field registered_entities table<uint, RegisteredEntity>
---@field constructron_statuses table<uint, table<ConstructronStatus, uint | boolean>>
---@field allowed_items table<string,boolean>
---@field items_to_place_cache table<string, {item: string, count: uint}>
---@field trash_items_cache table<table<string, uint>>
---@field stack_cache table<string,uint>
---@field water_tile_cache table<string, boolean>
---@field entity_inventory_cache table<table<string, uint>>
---@field managed_surfaces table<uint, string>
---@field station_requests table<uint, table<uint, table<string, uint>>>
--- ENTITIES
---@field construction_entities table<string, LuaEntity>
---@field deconstruction_entities table<string, LuaEntity>
---@field upgrade_entities table<string, UpgradeEntity>
---@field repair_entities table<string, LuaEntity>
---@field destroy_entities table<string, LuaEntity>
--- ENTIIY TICKS / TIMER
---@field construction_tick uint
---@field deconstruction_tick uint
---@field upgrade_tick uint
---@field repair_tick uint
---@field destroy_tick uint
--- QUEUES
---@field construction_queue EntityQueue
---@field deconstruction_queue EntityQueue
---@field upgrade_queue EntityQueue
---@field repair_queue EntityQueue
---@field destroy_queue EntityQueue
---@field cargo_queue table<uint, table<uint, table<uint, table<uint, LuaEntity, table<string, uint>>>>>
--- QUEUE INDEXES
---@field construction_index uint
---@field deconstruction_index uint
---@field upgrade_index uint
---@field repair_index uint
---@field destroy_index uint
---@field cargo_index uint
--- QUEUE TRIGGERS
---@field entity_proc_trigger boolean
---@field queue_proc_trigger boolean
---@field job_proc_trigger boolean
--- JOBS
---@field job_index uint
---@field jobs table<any, any>?
--- CONSTRUCTRONS & SERVICESTATIONS
---@field constructrons table<uint, LuaEntity>
---@field service_stations table<uint, LuaEntity?>
---@field constructrons_count table<int, int>
---@field available_ctron_count table<int, int>
---@field stations_count table<uint, uint>
--- SETTINGS
---@field construction_job_toggle boolean
---@field rebuild_job_toggle boolean
---@field deconstruction_job_toggle boolean
---@field upgrade_job_toggle boolean
---@field repair_job_toggle boolean
---@field destroy_job_toggle boolean
---@field debug_toggle boolean
---@field job_start_delay uint
---@field desired_robot_count uint
---@field desired_robot_name string
---@field repair_tool_name string
---@field construction_mat_alert uint
---@field entities_per_second uint
---@field spider_remote_toggle boolean
---@field ammo_name string
---@field ammo_count uint
---@field horde_mode boolean
--- UI
--- @field user_interface table<uint, any?>

-- set type of global (this will never get executed, only intellisense will see this)
---@type Global
__Constructron_Continued__global = {}
