local setting = storage.horde_mode

storage.horde_mode = {}

for _, surface in pairs(game.surfaces) do
    storage.horde_mode[surface.index] = setting
end

-------------------------------------------------------------------------------

game.print('Constructron-Continued: v2.0.24 migration complete!')
game.print('Please report any issues via discord! https://discord.gg/m9TDSsH3u2')