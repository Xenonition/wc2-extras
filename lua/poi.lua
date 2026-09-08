-- WC2 Extras — points of interest
-- Places neutral encounters and interactable locations on the map.

local on_event = wesnoth.game_events.add_repeating
local _ = wesnoth.textdomain 'wesnoth-wc2-extras'
local config = wc2x.config

local poi = {}

-- Neutral side number (last AI side). Set during place_all when sides are known.
poi.neutral_side = nil

-- POI type definitions
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

poi.creep_types = config.creep_types

-- Helper: wrap get_adjacent_hexes into a table
local function adjacent_hexes(loc_or_x, y)
	local results = { wesnoth.map.get_adjacent_hexes(loc_or_x, y) }
	return results
end

-- Find valid POI placement locations:
-- Not near keeps, on walkable terrain.
function poi.find_placement_candidates(min_distance_from_keep)
	min_distance_from_keep = min_distance_from_keep or 6
	local candidates = {}

	local keeps = wesnoth.map.find { terrain = "K*,*^K*" }

	local all_hexes = wesnoth.map.find {
		terrain = "G*,Hh*,Mm*,Dd*,Ss*,Aa*,Rb*,Rd*,Re*,Rr*,Rp*",
		wml.tag["not"] { terrain = "*^V*,C*,K*" },
	}

	for _, hex in ipairs(all_hexes) do
		local dominated = false
		for _, keep in ipairs(keeps) do
			local dist = wesnoth.map.distance_between(hex, keep)
			if dist < min_distance_from_keep then
				dominated = true
				break
			end
		end
		if not dominated then
			table.insert(candidates, hex)
		end
	end

	return candidates
end

-- Place POIs on the map
function poi.place_all()
	-- Determine neutral side: use the highest-numbered side
	poi.neutral_side = #wesnoth.sides

	local candidates = poi.find_placement_candidates()
	if #candidates == 0 then return end
	mathx.shuffle(candidates)

	local scenario_num = wc2_scenario.scenario_num()
	local placed = 0

	local available_types = {}
	for _, t in ipairs(poi.types) do
		table.insert(available_types, t)
	end
	mathx.shuffle(available_types)

	for i = 1, math.min(config.poi_count_per_map, #available_types, #candidates) do
		local poi_type = available_types[i]
		local loc = candidates[placed + 1]
		placed = placed + 1

		wesnoth.wml_actions.item {
			x = loc.x, y = loc.y,
			image = poi_type.image,
			z_order = 10,
		}

		wesnoth.wml_actions.label {
			x = loc.x, y = loc.y,
			text = poi_type.name,
		}

		-- Spawn guards on adjacent hexes
		if poi_type.guard_types and #poi_type.guard_types > 0 then
			local guard_min = poi_type.guard_count[1]
			local guard_max = poi_type.guard_count[2]
			local num_guards = mathx.random(guard_min, guard_max)
			local adj_hexes = adjacent_hexes(loc)
			mathx.shuffle(adj_hexes)
			local guards_placed = 0
			for _, adj in ipairs(adj_hexes) do
				if guards_placed >= num_guards then break end
				local existing = wesnoth.units.get(adj.x, adj.y)
				local terr = wesnoth.current.map[adj]
				if not existing and terr and not tostring(terr):match("[XQ]") then
					local gtype = poi_type.guard_types[mathx.random(#poi_type.guard_types)]
					wesnoth.wml_actions.unit {
						side = poi.neutral_side,
						type = gtype,
						x = adj.x, y = adj.y,
						generate_name = true,
						random_traits = true,
						upkeep = "free",
					}
					guards_placed = guards_placed + 1
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

	-- Place neutral creeps
	for i = 1, config.creep_count_per_map do
		if placed >= #candidates then break end
		placed = placed + 1
		local loc = candidates[placed]
		local ctype = poi.creep_types[mathx.random(#poi.creep_types)]
		wesnoth.wml_actions.unit {
			side = poi.neutral_side,
			type = ctype,
			x = loc.x, y = loc.y,
			generate_name = true,
			random_traits = true,
			upkeep = "free",
		}
	end

	-- Place caravan starting from scenario 2
	if scenario_num >= 2 and placed < #candidates then
		placed = placed + 1
		poi.place_caravan(candidates[placed])
	end
end

-- Caravan: a friendly unit the player needs to escort to safety
function poi.place_caravan(loc)
	wesnoth.wml_actions.unit {
		side = 1,
		type = "Ruffian",
		x = loc.x, y = loc.y,
		name = _ "Trade Caravan",
		generate_name = false,
		canrecruit = false,
		upkeep = "free",
		max_moves = 4,
		wml.tag.modifications {
			wml.tag.object {
				wml.tag.effect { apply_to = "hitpoints", increase_total = 10 },
			},
		},
		wml.tag.variables { wc2x_is_caravan = true },
	}

	wml.variables["wc2x_caravan.active"] = true
end

-- POI interaction: human unit steps on a cleared POI hex
on_event("moveto", function(cx)
	local u = wesnoth.units.get(cx.x1, cx.y1)
	if not u then return end
	if not wc2_scenario.is_human_side(u.side) then return end

	local poi_count = wml.variables["wc2x_poi.length"] or 0
	for i = 0, poi_count - 1 do
		local key = string.format("wc2x_poi[%d]", i)
		local px = wml.variables[key .. ".x"]
		local py = wml.variables[key .. ".y"]
		local ptype = wml.variables[key .. ".type"]
		local active = wml.variables[key .. ".active"]

		if active and cx.x1 == px and cx.y1 == py then
			-- Check no guards remain adjacent
			local guards_alive = false
			local adj_hexes = adjacent_hexes(px, py)
			for _, adj in ipairs(adj_hexes) do
				local guard = wesnoth.units.get(adj.x, adj.y)
				if guard and guard.side == poi.neutral_side then
					guards_alive = true
					break
				end
			end

			if not guards_alive then
				poi.activate(u, ptype, i)
				wml.variables[key .. ".active"] = false
			end
		end
	end
end)

-- Reward logic per POI type
function poi.activate(unit, poi_type, index)
	local scenario_num = wc2_scenario.scenario_num()
	local side = wesnoth.sides[unit.side]

	if poi_type == "ruins" then
		local gold = config.poi_gold_reward_base + (scenario_num * config.poi_gold_reward_per_scenario)
		if mathx.random(2) == 1 and wc2_artifacts then
			local artifact_list = wc2_artifacts.get_artifact_list()
			if #artifact_list > 0 then
				local artifact_id = mathx.random(#artifact_list)
				wesnoth.wml_actions.message {
					speaker = "narrator",
					caption = _ "Ancient Ruins",
					message = _ "Among the rubble, you discover a relic of power!",
					image = "scenery/castle-ruins.png",
				}
				wc2_artifacts.give_item(unit, artifact_id, true)
				return
			end
		end
		side.gold = side.gold + gold
		wesnoth.wml_actions.message {
			speaker = "narrator",
			caption = _ "Ancient Ruins",
			message = string.format(tostring(_ "You find %d gold hidden in the ruins."), gold),
			image = "scenery/castle-ruins.png",
		}

	elseif poi_type == "mercenary_camp" then
		local merc_types = {
			"Orcish Crossbowman", "Troll", "Ogre",
			"Assassin", "Rogue", "Huntsman",
		}
		local merc_type = merc_types[mathx.random(#merc_types)]
		local utype = wesnoth.unit_types[merc_type]
		local merc_cost = utype.cost

		if side.gold < merc_cost then
			wesnoth.wml_actions.message {
				speaker = "narrator",
				caption = _ "Mercenary Camp",
				message = string.format(
					tostring(_ "A %s offers their services for %d gold, but you cannot afford them."),
					utype.name, merc_cost
				),
				image = "scenery/tent-fancy-red.png",
			}
			return
		end

		-- Use wml_actions.message with options; result stored in wml.variables.value
		wesnoth.wml_actions.message {
			speaker = "narrator",
			caption = _ "Mercenary Camp",
			message = string.format(
				tostring(_ "A %s offers to join your cause for %d gold."),
				utype.name, merc_cost
			),
			image = "scenery/tent-fancy-red.png",
			wml.tag.option { label = string.format(tostring(_ "Hire (%dg)"), merc_cost) },
			wml.tag.option { label = _ "Decline" },
		}

		if wml.variables.value == 0 then
			local adj_hexes = adjacent_hexes(unit)
			for _, hex in ipairs(adj_hexes) do
				if not wesnoth.units.get(hex.x, hex.y) then
					wesnoth.wml_actions.unit {
						side = unit.side,
						type = merc_type,
						x = hex.x, y = hex.y,
						generate_name = true,
						random_traits = true,
						moves = 0,
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
			speaker = "narrator",
			caption = _ "Ancient Shrine",
			message = string.format(
				tostring(_ "The shrine's power flows into %s: %s!"),
				unit.name, tostring(buff.name)
			),
			image = "scenery/temple1.png",
		}
		unit:add_modification("object", {
			wml.tag.effect(buff.effect),
		})
	end
end

-- Caravan arrival check
on_event("moveto", function(cx)
	if not wml.variables["wc2x_caravan.active"] then return end
	local u = wesnoth.units.get(cx.x1, cx.y1)
	if not u then return end
	if not u.variables.wc2x_is_caravan then return end

	local terrain = tostring(wesnoth.current.map[{cx.x1, cx.y1}])
	if terrain:match("K") or terrain:match("C") then
		local nearby_leader = wesnoth.units.find_on_map({
			canrecruit = true,
			side = "1,2,3,4",
			wml.tag.filter_location { x = cx.x1, y = cx.y1, radius = 3 },
		})[1]
		if nearby_leader then
			local scenario_num = wc2_scenario.scenario_num()
			local gold = config.caravan_gold_reward_base + (scenario_num * config.caravan_gold_reward_per_scenario)
			local side = wesnoth.sides[nearby_leader.side]
			side.gold = side.gold + gold
			wesnoth.wml_actions.message {
				speaker = "narrator",
				caption = _ "Caravan Arrived!",
				message = string.format(
					tostring(_ "The trade caravan has reached safety. You receive %d gold!"),
					gold
				),
				image = "units/human-peasants/ruffian.png",
			}
			u:erase()
			wml.variables["wc2x_caravan.active"] = false
		end
	end
end)

-- Place POIs after WC2 sets up the map
on_event("start", function(cx)
	poi.place_all()
end)

return poi
