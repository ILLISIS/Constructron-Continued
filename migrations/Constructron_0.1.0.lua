for i, force in pairs(game.forces) do
    if force.technologies["spidertron"].researched == true then
        force.recipes["constructron"].enabled = true
        force.recipes["service_station"].enabled = true
    end
end
