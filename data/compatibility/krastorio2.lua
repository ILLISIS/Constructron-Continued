if mods["Krastorio2"] then
  local spider = data.raw["spider-vehicle"]["constructron"]
  if data.raw["spider-vehicle"]["constructron"] then
    spider.equipment_grid = "kr-spidertron-equipment-grid"
  end
  local spider_rocket = data.raw["spider-vehicle"]["constructron-rocket-powered"]
  if data.raw["spider-vehicle"]["constructron-rocket-powered"] then
    spider_rocket.equipment_grid = "kr-spidertron-equipment-grid"
  end
end
