---@meta
-- DO NOT REQUIRE THIS FILE ANYWHERE! THIS IS ONLY FOR INTELLISENSE

-- [ALIASES]

---@alias Area BoundingBox

---@alias ItemCounts table<string, integer>

---@alias EntityQueue table<uint, table<string, Chunk>>

---@alias ConstructronStatus
---| "build_tick"
---| "busy"
---| "deconstruct_tick"

---@alias BuildType
---| "deconstruction"
---| "construction"
---| "repair"
---| "upgrade"

---@alias JobType
---| "deconstruct"
---| "construct"
---| "upgrade"
---| "repair"

---@alias JobAction
---| "request_items"
---| "go_to_position"
---| "build"
---| "deconstruct"
---| "check_build_chunk"
---| "check_decon_chunk"
---| "check_upgrade_chunk"
---| "clear_items"
---| "retire"

---@alias JobLeaveCondition
---| "request_done"
---| "position_done"
---| "build_done"
---| "upgrade_done"
---| "deconstruction_done"
---| "pass"

---@alias JobBundle table<uint, Job[]>

-- [CLASSES]

-- extends vanilla pathfinder request parameters
---@class LuaSurface.request_path_param
---@field unit LuaEntity?
---@field units LuaEntity[]
---@field request_tick uint?
---@field initial_target MapPosition?

-- -@class Chunk
---@field area Area
---@field key string
---@field surface uint
-- -@field force LuaForce
---@field minimum MapPosition
---@field maximum MapPosition
-- -@field position MapPosition
---@field merged boolean?
---@field required_items ItemCounts
---@field trash_items ItemCounts

---@class Job
---@field active boolean?
---@field action JobAction
---@field action_args table, <any>?
---@field leave_condition JobLeaveCondition
---@field leave_args table, <any>?
---@field constructron LuaEntity
---@field unused_stations table<uint, LuaEntity>?
---@field job_class JobType?
---@field returning_home boolean?
---@field index uint
---@field bundle_index integer
---@field landfill_job boolean?
---@field attempt uint
---@field path_active boolean?
---@field path_requestid uint
---@field start_tick integer
---@field robot_positions table

---@class RegisteredEntity
---@field name string
---@field surface uint

---@class UpgradeEntity
---@field entity LuaEntity
---@field target LuaEntityPrototype?

---@class Global
--- PATHFINDER
---@field pathfinder_requests table<uint, LuaSurface.request_path_param>
--- MISC
---@field registered_entities table<uint, RegisteredEntity>
---@field constructron_statuses table<uint, table<ConstructronStatus, uint | boolean>>
---@field allowed_items table<string,boolean>
---@field stack_cache table<string,uint>
--- ENTITIES
---@field ghost_entities table<string, LuaEntity>
---@field deconstruction_entities table<string, LuaEntity>
---@field upgrade_entities table<string, UpgradeEntity>
---@field repair_entities table<string, LuaEntity>
--- QUEUES
---@field construct_queue EntityQueue
---@field deconstruct_queue EntityQueue
---@field upgrade_queue EntityQueue
---@field repair_queue EntityQueue
--- JOBS
---@field job_bundles JobBundle
---@field job_bundle_index uint
--- CONSTRUCTRONS & SERVICESTATIONS
---@field constructrons table<uint, LuaEntity>
---@field service_stations table<uint, LuaEntity?>
---@field constructrons_count table<uint, uint>
---@field stations_count table<uint, uint>
--- SETTINGS
---@field construction_job_toggle boolean
---@field rebuild_job_toggle boolean
---@field deconstruction_job_toggle boolean
---@field upgrade_job_toggle boolean
---@field repair_job_toggle boolean
---@field debug_toggle boolean
---@field job_start_delay uint
---@field desired_robot_count uint
---@field desired_robot_name string
---@field construction_mat_alert uint
---@field entities_per_tick uint
---@field clear_robots_when_idle boolean
---@field spider_remote_toggle boolean

-- set type of global (this will never get executed, only intellisense will see this)
---@type Global
__Constructron_Continued__global = {}
