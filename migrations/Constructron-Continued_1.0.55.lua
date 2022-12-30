--So, when path cache is enabled, negative path cache is also enabled.
--The problem is, when a single unit inside a nest can't get to the silo,
--He tells all other biters nearby that they also can't get to the silo.
--Which causes whole groups of them just to chillout and idle...
--This applies to all paths as the pathfinder is generic - Klonan
game.map_settings.path_finder.use_path_cache = false
global.spider_remote_toggle = false
game.print('Constructron-Continued: v1.0.55 migration complete!')