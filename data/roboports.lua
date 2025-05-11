local roboports = data.raw["roboport-equipment"]
local reduced_roboports = {}

for name, eq in pairs(roboports) do
   -- Only proceed if it's a roboport-equipment with construction_radius defined
   if eq.construction_radius then
      -- Always create radius 1 and 0 variants
      for radius = 1, 0, -1 do
         local eq_copy = table.deepcopy(eq)
         eq_copy.construction_radius = radius
         eq_copy.localised_name = {"equipment-name." .. name}
         eq_copy.name = name .. "-reduced-" .. radius
         if not eq_copy.take_result then
            eq_copy.take_result = name
         end
         table.insert(reduced_roboports, eq_copy)
      end
   end
end

data:extend(reduced_roboports)
