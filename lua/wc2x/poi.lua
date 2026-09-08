-- WC2 Extras — points of interest

local on_event = wesnoth.game_events.add_repeating
local _ = wesnoth.textdomain 'wesnoth-wc'

local poi = {}

function poi.init(config)
	poi.config = config
end

poi.types = {
	{
		id = "ruins",
		name = _ "Ancient Ruins",
		image = "scenery/castle-ruins.png",
		guard_types = { "Skeleton", "Skeleton Archer", "Ghost", "Ghoul" },
		guard_count = { 1, 2 },
	},
	{
		id = "mercenary_camp",
		name = _ "Mercenary Camp",
		image = "scenery/tent-fancy-red.png",
		guard_types = nil,
		guard_count = { 0, 0 },
	},
	{
		id = "shrine",
		name = _ "Ancient Shrine",
		image = "scenery/temple1.png",
		guard_types = { "Fire Guardian", "Elvish Druid", "Elvish Sorceress", "Mage" },
		guard_count = { 2, 3 },
	},
}

local function adjacent_hexes(loc_or_x, y)
	return { wesnoth.map.get_adjacent_hexes(loc_or_x, y) }
end

function poi.find_placement_candidates(min_distance_from_keep)
	min_distance_from_keep = min_distance_from_keep or 6
	local candidates = {}
	local keeps = wesnoth.map.find { terrain = "K*,*^K*" }
	local all_hexes = wesnoth.map.find {
		terrain = "G*,Hh*,Mm*,Dd*,Ss*,Aa*,Rb*,Rd*,Re*,Rr*,Rp*",
		wml.tag["not"] { terrain = "*^V*,C*,K*" },
	}
	for _, hex in ipairs(all_hexes) do
		local too_close = false
		for _, keep in ipairs(keeps) do
			if wesnoth.map.distance_between(hex, keep) < min_distance_from_keep then
				too_close = true
				break
			end
		end
		if not too_close then
			table.insert(candidates, hex)
		end
	end
	return candidates
end

function poi.place_all()
	poi.neutral_side = #wesnoth.sides
	local config = poi.config
	local candidates = poi.find_placement_candidates()
	if #candidates == 0 then return end
	mathx.shuffle(candidates)

	local scenario_num = wc2_scenario.scenario_num()
	local placed = 0

	local available_types = {}
	for _, t in ipairs(poi.types) do table.insert(available_types, t) end
	mathx.shuffle(available_types)

	for i = 1, math.min(config.poi_count_per_map, #available_types, #candidates) do
		local poi_type = available_types[i]
		placed = placed + 1
		local loc = candidates[placed]

		wesnoth.wml_actions.item { x = loc.x, y = loc.y, image = poi_type.image, z_order = 10 }
		wesnoth.wml_actions.label { x = loc.x, y = loc.y, text = poi_type.name }

		if poi_type.guard_types and #poi_type.guard_types > 0 then
			local num_guards = mathx.random(poi_type.guard_count[1], poi_type.guard_count[2])
			local adj = adjacent_hexes(loc)
			mathx.shuffle(adj)
			local g = 0
			for _, a in ipairs(adj) do
				if g >= num_guards then break end
				if not wesnoth.units.get(a.x, a.y) then
					local terr = wesnoth.current.map[a]
					if terr and not tostring(terr):match("[XQ]") then
						wesnoth.wml_actions.unit {
							side = poi.neutral_side,
							type = poi_type.guard_types[mathx.random(#poi_type.guard_types)],
							x = a.x, y = a.y,
							generate_name = true, random_traits = true, upkeep = "free",
						}
						g = g + 1
					end
				end
			end
		end

		local key = string.format("wc2x_poi[%d]", i - 1)
		wml.variables[key .. ".x"] = loc.x
		wml.variables[key .. ".y"] = loc.y
		wml.variables[key .. ".type"] = poi_type.id
		wml.variables[key .. ".active"] = true
	end
	wml.variables["wc2x_poi.length"] = math.min(config.poi_count_per_map, #available_types, #candidates)

	for i = 1, config.creep_count_per_map do
		if placed >= #candidates then break end
		placed = placed + 1
		local loc = candidates[placed]
		wesnoth.wml_actions.unit {
			side = poi.neutral_side,
			type = config.creep_types[mathx.random(#config.creep_types)],
			x = loc.x, y = loc.y,
			generate_name = true, random_traits = true, upkeep = "free",
		}
	end

	if scenario_num >= 2 and placed < #candidates then
		placed = placed + 1
		poi.place_caravan(candidates[placed])
	end
end

function poi.place_caravan(loc)
	wesnoth.wml_actions.unit {
		side = 1, type = "Ruffian",
		x = loc.x, y = loc.y,
		name = _ "Trade Caravan", generate_name = false,
		canrecruit = false, upkeep = "free", max_moves = 4,
		wml.tag.modifications {
			wml.tag.object { wml.tag.effect { apply_to = "hitpoints", increase_total = 10 } },
		},
		wml.tag.variables { wc2x_is_caravan = true },
	}
	wml.variables["wc2x_caravan.active"] = true
end

on_event("moveto", function(cx)
	local u = wesnoth.units.get(cx.x1, cx.y1)
	if not u or not wc2_scenario.is_human_side(u.side) then return end

	local poi_count = wml.variables["wc2x_poi.length"] or 0
	for i = 0, poi_count - 1 do
		local key = string.format("wc2x_poi[%d]", i)
		local px = wml.variables[key .. ".x"]
		local py = wml.variables[key .. ".y"]
		local active = wml.variables[key .. ".active"]

		if active and cx.x1 == px and cx.y1 == py then
			local guards_alive = false
			for _, adj in ipairs(adjacent_hexes(px, py)) do
				local guard = wesnoth.units.get(adj.x, adj.y)
				if guard and guard.side == poi.neutral_side then
					guards_alive = true
					break
				end
			end
			if not guards_alive then
				poi.activate(u, wml.variables[key .. ".type"], i)
				wml.variables[key .. ".active"] = false
			end
		end
	end
end)

function poi.activate(unit, poi_type, index)
	local config = poi.config
	local scenario_num = wc2_scenario.scenario_num()
	local side = wesnoth.sides[unit.side]

	if poi_type == "ruins" then
		local gold = config.poi_gold_reward_base + (scenario_num * config.poi_gold_reward_per_scenario)
		if mathx.random(2) == 1 and wc2_artifacts then
			local artifact_list = wc2_artifacts.get_artifact_list()
			if #artifact_list > 0 then
				local artifact_id = mathx.random(#artifact_list)
				wesnoth.wml_actions.message {
					speaker = "narrator", caption = _ "Ancient Ruins",
					message = _ "Among the rubble, you discover a relic of power!",
					image = "scenery/castle-ruins.png",
				}
				wc2_artifacts.give_item(unit, artifact_id, true)
				return
			end
		end
		side.gold = side.gold + gold
		wesnoth.wml_actions.message {
			speaker = "narrator", caption = _ "Ancient Ruins",
			message = string.format(tostring(_ "You find %d gold hidden in the ruins."), gold),
			image = "scenery/castle-ruins.png",
		}

	elseif poi_type == "mercenary_camp" then
		local merc_types = { "Orcish Crossbowman", "Troll", "Ogre", "Assassin", "Rogue", "Huntsman" }
		local merc_type = merc_types[mathx.random(#merc_types)]
		local utype = wesnoth.unit_types[merc_type]
		local merc_cost = utype.cost

		if side.gold < merc_cost then
			wesnoth.wml_actions.message {
				speaker = "narrator", caption = _ "Mercenary Camp",
				message = string.format(tostring(_ "A %s offers their services for %d gold, but you cannot afford them."), utype.name, merc_cost),
				image = "scenery/tent-fancy-red.png",
			}
			return
		end

		wesnoth.wml_actions.message {
			speaker = "narrator", caption = _ "Mercenary Camp",
			message = string.format(tostring(_ "A %s offers to join your cause for %d gold."), utype.name, merc_cost),
			image = "scenery/tent-fancy-red.png",
			wml.tag.option { label = string.format(tostring(_ "Hire (%dg)"), merc_cost) },
			wml.tag.option { label = _ "Decline" },
		}
		if wml.variables.value == 0 then
			for _, hex in ipairs(adjacent_hexes(unit)) do
				if not wesnoth.units.get(hex.x, hex.y) then
					wesnoth.wml_actions.unit {
						side = unit.side, type = merc_type,
						x = hex.x, y = hex.y,
						generate_name = true, random_traits = true, moves = 0,
					}
					side.gold = side.gold - merc_cost
					break
				end
			end
		end

	elseif poi_type == "shrine" then
		local buffs = {
			{ name = _ "+1 Melee Damage", effect = { apply_to = "attack", range = "melee", increase_damage = 1 } },
			{ name = _ "+1 Ranged Damage", effect = { apply_to = "attack", range = "ranged", increase_damage = 1 } },
			{ name = _ "+4 Hitpoints", effect = { apply_to = "hitpoints", increase_total = 4 } },
			{ name = _ "+1 Movement", effect = { apply_to = "movement", increase = 1 } },
		}
		local buff = buffs[mathx.random(#buffs)]
		wesnoth.wml_actions.message {
			speaker = "narrator", caption = _ "Ancient Shrine",
			message = string.format(tostring(_ "The shrine's power flows into %s: %s!"), unit.name, tostring(buff.name)),
			image = "scenery/temple1.png",
		}
		unit:add_modification("object", { wml.tag.effect(buff.effect) })
	end
end

-- Caravan arrival
on_event("moveto", function(cx)
	if not wml.variables["wc2x_caravan.active"] then return end
	local u = wesnoth.units.get(cx.x1, cx.y1)
	if not u or not u.variables.wc2x_is_caravan then return end

	local terrain = tostring(wesnoth.current.map[{cx.x1, cx.y1}])
	if terrain:match("K") or terrain:match("C") then
		local nearby_leader = wesnoth.units.find_on_map({
			canrecruit = true, side = "1,2,3,4",
			wml.tag.filter_location { x = cx.x1, y = cx.y1, radius = 3 },
		})[1]
		if nearby_leader then
			local config = poi.config
			local gold = config.caravan_gold_reward_base + (wc2_scenario.scenario_num() * config.caravan_gold_reward_per_scenario)
			wesnoth.sides[nearby_leader.side].gold = wesnoth.sides[nearby_leader.side].gold + gold
			wesnoth.wml_actions.message {
				speaker = "narrator", caption = _ "Caravan Arrived!",
				message = string.format(tostring(_ "The trade caravan has reached safety. You receive %d gold!"), gold),
				image = "units/human-peasants/ruffian.png",
			}
			u:erase()
			wml.variables["wc2x_caravan.active"] = false
		end
	end
end)

on_event("start", function(cx)
	poi.place_all()
end)

return poi
