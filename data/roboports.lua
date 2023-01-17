-- create copies of roboports with reduced construction radius
local roboports = data.raw["roboport-equipment"]
local reduced_roboports = {}

for name, eq in pairs(roboports) do
   local max_radius = math.min(eq.construction_radius, 1)
   -- skip if equipment has no construction radius
   if not (max_radius == 0) then
      -- create copies with reduced construction radius
      for i=0, max_radius do
         local eq_copy = table.deepcopy(eq)
         eq_copy.construction_radius = i
         eq_copy.localised_name = {"equipment-name." .. name}
         eq_copy.name = name .. "-reduced-" .. i;
         if not eq.take_result then
            eq_copy.take_result = name
         end
         table.insert(reduced_roboports, eq_copy)
      end
   end
end

data:extend(reduced_roboports)
