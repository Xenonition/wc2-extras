-- WC2 Extras — forked campaign main
-- Based on World Conquest II, with income-based economy, POIs, shop, and upgrades.

T = wml.tag
on_event = wesnoth.game_events.add_repeating

wesnoth.dofile("./game_mechanics/_load.lua")

wc2_era = wesnoth.require("./era/era.lua")

-- Load WC2X modules before enemy/scenario (they hook into the same events)
wc2x = {}
wc2x.config = wesnoth.dofile("./wc2x/config.lua")
wc2x.upgrades = wesnoth.dofile("./wc2x/upgrades.lua")
wc2x.upgrades.init(wc2x.config)
wc2x.poi = wesnoth.dofile("./wc2x/poi.lua")
wc2x.poi.init(wc2x.config)
wc2x.shop = wesnoth.dofile("./wc2x/shop.lua")
wc2x.shop.init(wc2x.config, wc2x.upgrades)

wc2_enemy = wesnoth.dofile("./campaign/enemy.lua")

wc2_scenario = wesnoth.dofile("./campaign/scenario.lua")
wesnoth.dofile("./campaign/autorecall.lua")
wesnoth.dofile("./campaign/objectives.lua")
wesnoth.dofile("./campaign/enemy_themed.lua")

on_event("prestart", function(cx)
	wesnoth.wml_actions.wc2_fix_colors {
		wml.tag.player_sides {
			side="1,2,3,4",
			wml.tag.has_unit {
				canrecruit = true,
			}
		}
	}
end)
