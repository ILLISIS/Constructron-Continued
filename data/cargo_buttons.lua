local ctron_import = table.deepcopy(data.raw["utility-sprites"]["default"]["import"])
ctron_import.name = "ctron_import"
ctron_import.type = "sprite"
ctron_import.filename = "__Constructron-Continued__/graphics/import.png"

local ctron_export = table.deepcopy(data.raw["utility-sprites"]["default"]["export"])
ctron_export.name = "ctron_export"
ctron_export.type = "sprite"
ctron_export.filename = "__Constructron-Continued__/graphics/export.png"


data:extend({ctron_import, ctron_export})