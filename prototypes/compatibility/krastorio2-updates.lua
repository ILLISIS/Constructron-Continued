if not mods["Krastorio2"] then return end

local spider = data.raw["spider-vehicle"]["constructron"]
if spider then
  local grid_name = spider.equipment_grid
  if grid_name then
    local grid = data.raw["equipment-grid"][grid_name]
    if grid then
      table.insert(grid.equipment_categories, "universal-equipment")
      table.insert(grid.equipment_categories, "robot-interaction-equipment")
      table.insert(grid.equipment_categories, "vehicle-robot-interaction-equipment")
      table.insert(grid.equipment_categories, "vehicle-equipment")
      table.insert(grid.equipment_categories, "vehicle-motor")
    end
  end
end
