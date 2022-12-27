-- from ClosestFirstOneDotOne
local roboports = {}
for name, eq in pairs(data.raw["roboport-equipment"]) do
   roboports[name] = eq
end
for _, eq in pairs(roboports) do
   local radius = eq.construction_radius
   for i=0, radius do
      local robocopy = table.deepcopy(eq)
      robocopy.construction_radius = i
      robocopy.localised_name = {"equipment-name." .. robocopy.name}
      robocopy.name = robocopy.name .. "-reduced-" .. i;
      if not eq.take_result then
         robocopy.take_result = eq.name
      end
      data:extend{robocopy};
   end
end
