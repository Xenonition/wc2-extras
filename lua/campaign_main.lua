-- World Conquest III — forked campaign main

T = wml.tag
on_event = wesnoth.game_events.add_repeating

wesnoth.dofile("./game_mechanics/_load.lua")

wc2_era = wesnoth.require("./era/era.lua")

-- Load WC3 modules before enemy/scenario (they hook into the same events)
wc2x = {}
wc2x.config = wesnoth.dofile("./wc2x/config.lua")
wc2x.dialog_utils = wesnoth.dofile("./wc2x/dialog_utils.lua")
wc2x.upgrades = wesnoth.dofile("./wc2x/upgrades.lua")
wc2x.upgrades.init(wc2x.config)
wc2x.poi = wesnoth.dofile("./wc2x/poi.lua")
wc2x.poi.init(wc2x.config)
wc2x.shop = wesnoth.dofile("./wc2x/shop.lua")
wc2x.shop.init(wc2x.config, wc2x.upgrades)

wc2_enemy = wesnoth.dofile("./campaign/enemy.lua")
wc2x.enemy_scaling = wesnoth.dofile("./wc2x/enemy_scaling.lua")
wc2x.enemy_scaling.init(wc2x.config)
wc2x.ai_director = wesnoth.dofile("./wc2x/ai_director.lua")
wc2x.ai_director.init(wc2x.config)
wc2x.debug = wc2x.ai_director.debug
wc2x.debug_panel = wesnoth.dofile("./wc2x/debug_panel.lua")
wc2x.debug_panel.init(wc2x.config)
wc2x.final_boss = wesnoth.dofile("./wc2x/final_boss.lua")
wc2x.final_boss.init(wc2x.config)
wc2x.unit_finder = wesnoth.dofile("./wc2x/unit_finder.lua")
wc2x.unit_finder.init()
wc2x.unit_pool = wesnoth.dofile("./wc2x/unit_pool.lua")
wc2x.gacha_hero = wesnoth.dofile("./wc2x/gacha_hero.lua")

wc2_scenario = wesnoth.dofile("./campaign/scenario.lua")
wesnoth.dofile("./campaign/autorecall.lua")
wesnoth.dofile("./campaign/objectives.lua")
wesnoth.dofile("./campaign/enemy_themed.lua")

-- LotI Era workaround: DROPS die event has side=1..12 baked at preprocess,
-- so player-unit deaths drop items with dropping_side=player. The pickup
-- filter then excludes the player from picking them up. Clear dropping_side
-- for human sides so the player can loot items from their own fallen units.
if loti and loti.item and loti.item.on_the_ground and loti.item.on_the_ground.add then
	local loti_orig_ground_add = loti.item.on_the_ground.add
	loti.item.on_the_ground.add = function(item_number, x, y, crafted_sort, turn, dropping_side)
		if dropping_side and wc2_scenario.is_human_side(tonumber(dropping_side) or 0) then
			dropping_side = 0
		end
		return loti_orig_ground_add(item_number, x, y, crafted_sort, turn, dropping_side)
	end
end

-- LotI Era workaround: item_pick fires for AI sides because LotI's
-- controller=human filter is ignored by the engine. See DESIGN.md.
if wesnoth.wml_actions.item_pick_menu then
	local loti_orig_item_pick_menu = wesnoth.wml_actions.item_pick_menu
	wesnoth.wml_actions.item_pick_menu = function(cfg)
		local unit = wesnoth.units.find_on_map(cfg)[1]
		if unit and not wc2_scenario.is_human_side(unit.side) then return end
		loti_orig_item_pick_menu(cfg)
	end
end

-- LotI Era workaround: auto-collect all ground items on victory.
-- LotI only auto-picks items dropped on the final turn or on impassable
-- terrain; everything else is lost. Collect them all into storage first.
if loti and loti.item and loti.item.storage then
	on_event("victory", function()
		local items = wml.array_access.get("items")
		if #items == 0 then return end
		for _, elem in ipairs(items) do
			local item_number = elem.type
			local sort = elem.sort
			loti.item.storage.add(item_number, sort)
			wesnoth.wml_actions.remove_item { x = elem.x, y = elem.y }
		end
		wml.array_access.set("items", {})
	end)
end

on_event("prestart", function(cx)
	wesnoth.wml_actions.wc2_fix_colors {
		wml.tag.player_sides {
			side="1,2,3,4",
			wml.tag.has_unit {
				canrecruit = true,
			}
		}
	}

	-- LotI Era workaround: DROPS macro hardcodes enemy_sides to 1-12,
	-- which includes the player. Rebuild to actual enemy sides only.
	if wml.variables["enemy_sides"] then
		local enemy_list = {}
		for i = 1, #wesnoth.sides do
			local s = wesnoth.sides[i]
			if not wc2_scenario.is_human_side(i) and not s.variables["wc2x_is_neutral"] then
				table.insert(enemy_list, tostring(i))
			end
		end
		wml.variables["enemy_sides"] = table.concat(enemy_list, ",")
	end
end)
