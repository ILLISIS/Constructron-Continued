local station_combinator = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
station_combinator.name = "ctron-combinator"
station_combinator.sprites = nil
station_combinator.selectable_in_game = false
station_combinator.item_slot_count = 100
station_combinator.draw_circuit_wires = false
station_combinator.flags = { "hide-alt-info", "not-blueprintable", "not-on-map", }

data:extend({station_combinator})