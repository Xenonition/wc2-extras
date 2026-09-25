-- WC2 Extras — points of interest
-- Uses WC2's [item] + wc2_drop_pickup pattern for pickup detection.

local on_event = wesnoth.game_events.add_repeating
local _ = wesnoth.textdomain 'wesnoth-wc'

local merc_dialog_wml = wml.load "~add-ons/wc2-extras/gui/merc_dialog.cfg"

local poi = {}

function poi.init(config)
	poi.config = config
end

-- Lazily resolve the neutral side — survives save/load where "start" doesn't re-fire.
function poi.get_neutral_side()
	if poi.neutral_side then return poi.neutral_side end
	for i = 1, #wesnoth.sides do
		if wesnoth.sides[i].variables["wc2x_is_neutral"] then
			poi.neutral_side = i
			return i
		end
	end
	poi.neutral_side = #wesnoth.sides
	return poi.neutral_side
end

poi.types = {
	{
		id = "ruins",
		name = _ "Ancient Ruins",
		image = "scenery/castle-ruins.png",
		guard_types = nil,
		guard_count = { 0, 0 },
		ambush_types = { "Skeleton", "Walking Corpse", "Wolf", "Vampire Bat", "Footpad", "Poacher", "Mudcrawler" },
		ambush_count = { 1, 3 },
		weight = 3,
	},
	{
		id = "mercenary_camp",
		name = _ "Mercenary Camp",
		image = "scenery/tent-fancy-red.png",
		guard_types = nil,
		guard_count = { 0, 0 },
		weight = 2,
	},
	{
		id = "shrine",
		name = _ "Ancient Shrine",
		image = "scenery/temple1.png",
		guard_types = { "Orcish Warrior", "Troll Whelp", "Wolf Rider", "Footpad", "Poacher", "Thug", "Mage" },
		guard_count = { 2, 3 },
		weight = 2,
	},
	{
		id = "caravan",
		name = _ "Trade Caravan",
		image = "units/human-peasants/ruffian.png",
		guard_types = nil,
		guard_count = { 0, 0 },
		weight = 1,
		min_scenario = 2,
	},
}

function poi.get_mercenary_pool()
	local by_level = {}
	for lv = 1, 6 do
		local pool = wc2x.unit_pool.get(lv)
		if #pool > 0 then
			by_level[lv] = pool
		end
	end
	return by_level
end

local function get_merc_level_weights(scenario_num)
	local cfg = poi.config.merc_level_weights
	if not cfg then return { [2] = 10 } end
	local best = cfg[1].weights
	for _, entry in ipairs(cfg) do
		if scenario_num >= entry.scenario then best = entry.weights end
	end
	return best
end

local function pick_weighted_merc(by_level, level_weights)
	local total_w = 0
	local candidates = {}
	for lvl, w in pairs(level_weights) do
		if by_level[lvl] and #by_level[lvl] > 0 then
			total_w = total_w + w
			table.insert(candidates, { level = lvl, weight = w })
		end
	end
	table.sort(candidates, function(a, b) return a.level < b.level end)
	if total_w == 0 then return nil end
	local roll = mathx.random(total_w)
	local sum = 0
	for _, c in ipairs(candidates) do
		sum = sum + c.weight
		if roll <= sum then
			local pool = by_level[c.level]
			return pool[mathx.random(#pool)], c.level
		end
	end
	return nil
end

local function adjacent_hexes(loc_or_x, y)
	if not loc_or_x then return {} end
	if type(loc_or_x) == "number" then
		return { wesnoth.map.get_adjacent_hexes(loc_or_x, y) }
	end
	if loc_or_x.x and loc_or_x.y then
		return { wesnoth.map.get_adjacent_hexes(loc_or_x.x, loc_or_x.y) }
	end
	return { wesnoth.map.get_adjacent_hexes(loc_or_x) }
end

function poi.find_placement_candidates(min_distance_from_keep)
	min_distance_from_keep = min_distance_from_keep or 6
	local candidates = {}
	local keeps = wesnoth.map.find { terrain = "K*,*^K*" }
	local map_w, map_h = wesnoth.current.map.playable_width, wesnoth.current.map.playable_height
	local border = wesnoth.current.map.border_size or 1
	local all_hexes = wesnoth.map.find {
		terrain = "G*,Hh*,Mm*,Dd*,Ss*,Aa*,Rb*,Rd*,Re*,Rr*,Rp*",
		wml.tag["not"] { terrain = "*^V*,C*,K*,X*,Q*" },
	}
	for _, hex in ipairs(all_hexes) do
		if hex.x > border and hex.y > border and hex.x <= map_w and hex.y <= map_h then
			local too_close = false
			for _, keep in ipairs(keeps) do
				if wesnoth.map.distance_between(hex, keep) < min_distance_from_keep then
					too_close = true
					break
				end
			end
			if not too_close then
				local adj = { wesnoth.map.get_adjacent_hexes(hex) }
				local reachable = 0
				for _, a in ipairs(adj) do
					local t = wesnoth.current.map[a]
					if t and not tostring(t):match("[XQ]") then
						reachable = reachable + 1
					end
				end
				if reachable >= 3 then
					table.insert(candidates, hex)
				end
			end
		end
	end
	return candidates
end

local function resolve_guard_tier(poi_id, scenario_num)
	local scaling = poi.config.poi_guard_scaling
	if not scaling or not scaling[poi_id] then return nil end
	local tiers = scaling[poi_id]
	local best = nil
	for _, tier in ipairs(tiers) do
		if scenario_num >= tier.scenario then best = tier end
	end
	return best
end

local function weighted_pick(pool)
	local total = 0
	for _, entry in ipairs(pool) do total = total + entry.weight end
	local roll = mathx.random(total)
	local sum = 0
	for i, entry in ipairs(pool) do
		sum = sum + entry.weight
		if roll <= sum then return i, entry end
	end
	return #pool, pool[#pool]
end

function poi.place_all()
	local player_count = wml.variables.wc2_player_count or 1
	-- Find the dedicated neutral side (marked with wc2x_is_neutral variable),
	-- added after all enemy sides. Uses idle_ai so guards never move.
	poi.neutral_side = nil
	for i = 1, #wesnoth.sides do
		if wesnoth.sides[i].variables["wc2x_is_neutral"] then
			poi.neutral_side = i
			break
		end
	end
	if not poi.neutral_side then
		poi.neutral_side = #wesnoth.sides
	end
	local config = poi.config
	local candidates = poi.find_placement_candidates()
	if #candidates == 0 then return end
	mathx.shuffle(candidates)

	local scenario_num = wc2_scenario.scenario_num()
	local placed = 0

	local pool = {}
	for _, t in ipairs(poi.types) do
		if not t.min_scenario or scenario_num >= t.min_scenario then
			table.insert(pool, { poi_type = t, weight = t.weight or 1 })
		end
	end

	local poi_count = config.poi_base_count + math.floor((scenario_num - 1) * config.poi_per_scenario)
	poi_count = math.min(poi_count, #candidates)

	for _ = 1, poi_count do
		if #pool == 0 or placed >= #candidates then break end
		local _, pick = weighted_pick(pool)
		local poi_type = pick.poi_type
		placed = placed + 1
		local loc = candidates[placed]

		wesnoth.wml_actions.item {
			x = loc.x, y = loc.y, image = poi_type.image, z_order = 10,
			wml.tag.variables { wc2x_poi_type = poi_type.id },
		}
		wesnoth.wml_actions.label { x = loc.x, y = loc.y, text = poi_type.name }

		local guard_types = poi_type.guard_types
		local guard_count = poi_type.guard_count
		if not poi_type.ambush_types then
			local tier = resolve_guard_tier(poi_type.id, scenario_num)
			if tier then guard_types = tier.types; guard_count = tier.count end
		end
		if guard_types and #guard_types > 0 then
			local num_guards = mathx.random(guard_count[1], guard_count[2])
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
							type = guard_types[mathx.random(#guard_types)],
							x = a.x, y = a.y,
							generate_name = true, random_traits = true, upkeep = "free",
							wml.tag.ai { ai_special = "guardian" },
						}
						g = g + 1
					end
				end
			end
		end
	end

	for i = 1, config.creep_count_per_map do
		if placed >= #candidates then break end
		placed = placed + 1
		local loc = candidates[placed]
		wesnoth.wml_actions.unit {
			side = poi.neutral_side,
			type = config.creep_types[mathx.random(#config.creep_types)],
			x = loc.x, y = loc.y,
			generate_name = true, random_traits = true, upkeep = "free",
			wml.tag.ai { ai_special = "guardian" },
		}
	end
end

-- Pickup via WC2's dropping.lua wc2_drop_pickup event.
-- dropping.lua fires this when any unit steps on an [item].
on_event("wc2_drop_pickup", function(ec)
	local item = wc2_dropping.current_item
	if not item or not item.variables.wc2x_poi_type then return end

	local side_num = wesnoth.current.side
	if not wc2_scenario.is_human_side(side_num) then return end

	local cx = wesnoth.current.event_context
	local x, y = cx.x1, cx.y1
	if not x or not y then return end

	local poi_type_id = item.variables.wc2x_poi_type

	-- Guard check: if any of THIS POI's guards are still alive, block pickup
	local poi_key = x .. "," .. y
	for _, adj in ipairs(adjacent_hexes(x, y)) do
		local guard = wesnoth.units.get(adj.x, adj.y)
		if guard and guard.variables.wc2x_poi_guard == poi_key then
			return
		end
	end

	local unit = wesnoth.units.get(x, y)
	if not unit then return end

	-- Ambush: spawn guards on first contact, block pickup until they're dead
	local poi_def = nil
	for _, t in ipairs(poi.types) do
		if t.id == poi_type_id then poi_def = t; break end
	end
	if poi_def and poi_def.ambush_types and not item.variables.wc2x_ambush_triggered then
		item.variables.wc2x_ambush_triggered = true
		local scenario_num = wc2_scenario.scenario_num()
		local tier = resolve_guard_tier(poi_def.id, scenario_num)
		local ambush_types = tier and tier.types or poi_def.ambush_types
		local ambush_count = tier and tier.count or poi_def.ambush_count
		local num = mathx.random(ambush_count[1], ambush_count[2])
		local adj = adjacent_hexes(x, y)
		mathx.shuffle(adj)
		local spawned = 0
		for _, a in ipairs(adj) do
			if spawned >= num then break end
			if not wesnoth.units.get(a.x, a.y) then
				local terr = wesnoth.current.map[a]
				if terr and not tostring(terr):match("[XQ]") then
					local u = wesnoth.units.create {
						side = poi.get_neutral_side(),
						type = ambush_types[mathx.random(#ambush_types)],
						x = a.x, y = a.y,
						generate_name = true, random_traits = true, upkeep = "free",
						wml.tag.ai { ai_special = "guardian" },
					}
					u.variables.wc2x_poi_guard = x .. "," .. y
					u:to_map()
					spawned = spawned + 1
				end
			end
		end
		if spawned > 0 then
			wesnoth.wml_actions.message {
				speaker = "narrator", caption = poi_def.name,
				message = _ "The dead stir as you disturb the ruins! Defeat them, then return to claim the treasure.",
				image = poi_def.image,
			}
			return
		end
	end

	local consumed = poi.activate(unit, poi_type_id)
	if consumed ~= false then
		wc2_dropping.remove_current_item()
		wesnoth.wml_actions.label { x = x, y = y, text = "" }
	end
end)

-- A trait buff the unit already carries adds nothing, and a new ability whose id the unit
-- already has is dropped by the engine; skip both so a shrine visit is never wasted
local function buff_is_redundant(unit, buff)
	local trait = buff.trait
	if not trait then return false end
	if unit:matches { wml.tag.filter_wml { wml.tag.modifications { wml.tag.trait { id = trait.id } } } } then
		return true
	end
	for i, effect in ipairs(trait) do
		if effect[1] == "effect" and effect[2].apply_to == "new_ability" then
			local abilities = wml.get_child(effect[2], "abilities")
			for j, ability in ipairs(abilities or {}) do
				if ability[2].name and unit:matches { ability = ability[2].id } then
					return true
				end
			end
		end
	end
	return false
end

function poi.activate(unit, poi_type)
	local config = poi.config
	local scenario_num = wc2_scenario.scenario_num()
	local side = wesnoth.sides[unit.side]

	if poi_type == "ruins" then
		local base = config.poi_gold_reward_base
		local per_sc = config.poi_gold_reward_per_scenario
		local gold_base = type(base) == "table" and mathx.random(base[1], base[2]) or base
		local gold_scale = type(per_sc) == "table" and mathx.random(per_sc[1], per_sc[2]) or per_sc
		local gold = gold_base + (scenario_num * gold_scale)
		if mathx.random(2) == 1 and wc2_artifacts then
			local artifact_list = wc2_artifacts.get_artifact_list()
			if #artifact_list > 0 then
				local artifact_id = mathx.random(#artifact_list)
				local drop_hex = nil
				for _, hex in ipairs(adjacent_hexes(unit)) do
					if not wesnoth.units.get(hex.x, hex.y) then
						local terr = wesnoth.current.map[hex]
						if terr and not tostring(terr):match("[XQ]") then
							drop_hex = hex
							break
						end
					end
				end
				if not drop_hex then drop_hex = { x = unit.x, y = unit.y } end
				wesnoth.wml_actions.message {
					speaker = "narrator", caption = _ "Ancient Ruins",
					message = _ "Among the rubble, you discover a relic of power!",
					image = "scenery/castle-ruins.png",
				}
				wc2_artifacts.place_item(drop_hex.x, drop_hex.y, artifact_id)
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
		local by_level = poi.get_mercenary_pool()
		local has_any = false
		for _, pool in pairs(by_level) do
			if #pool > 0 then has_any = true; break end
		end
		if not has_any then return false end
		local du = wc2x.dialog_utils

		local scenario_num = wc2_scenario.scenario_num()
		local level_weights = get_merc_level_weights(scenario_num)
		local offer_count = config.merc_offer_count or 3
		local cost_mult = config.merc_cost_multiplier or 1.2

		local seen_offers = {}
		local offers = {}
		for _ = 1, offer_count + 5 do
			if #offers >= offer_count then break end
			local name, lvl = pick_weighted_merc(by_level, level_weights)
			if name and not seen_offers[name] then
				seen_offers[name] = true
				local utype = wesnoth.unit_types[name]
				if utype then
					local cost = math.floor(utype.cost * cost_mult)
					table.insert(offers, { type_id = name, utype = utype, cost = cost, icon = utype.image, level = lvl })
				end
			end
		end

		if #offers == 0 then return false end

		local res = wesnoth.sync.evaluate_single(_ "Mercenary Camp", function()
			local gold_now = side.gold

			local function format_offer(o)
				local can_afford = gold_now >= o.cost
				local name_str = tostring(o.utype.name)
				if not can_afford then name_str = du.gray(name_str) end
				local price_str = can_afford
					and du.colored(string.format("%d gold", o.cost), "yellow")
					or du.gray(string.format("%d gold", o.cost))
				return { icon = o.icon, name = name_str, subtitle = price_str }
			end

			local hire_target = nil

			local function preshow(dialog)
				dialog.gold_label.label = du.gold_header(gold_now)
				local list = dialog.shop_list
				du.populate_list(list, offers, format_offer)
				list.on_modified = function()
					local idx = list.selected_index
					if idx and idx >= 1 and idx <= #offers then
						hire_target = offers[idx]
						dialog.detail_text.label = du.unit_detail_text(hire_target.utype, gold_now, hire_target.cost)
					end
				end
				if #offers > 0 then
					list.selected_index = 1
					hire_target = offers[1]
					dialog.detail_text.label = du.unit_detail_text(hire_target.utype, gold_now, hire_target.cost)
				end
			end

			local d_wml = wml.get_child(merc_dialog_wml, 'resolution')
			if not d_wml then return { hire = "" } end
			local d_res = gui.show_dialog(d_wml, preshow)

			if d_res ~= -1 or not hire_target or gold_now < hire_target.cost then
				return { hire = "" }
			end
			return { hire = hire_target.type_id .. ":" .. tostring(hire_target.cost) }
		end, function() return { hire = "" } end, unit.side)

		local hire_str = res.hire or ""
		if hire_str == "" then return false end
		local type_id, cost_str = hire_str:match("^(.-):(.+)$")
		local cost = tonumber(cost_str)
		if not type_id or not cost then return false end

		local spawn_hex = nil
		for _, hex in ipairs(adjacent_hexes(unit)) do
			if not wesnoth.units.get(hex.x, hex.y) then
				local terr = wesnoth.current.map[hex]
				if terr and not tostring(terr):match("[XQ]") then
					spawn_hex = hex
					break
				end
			end
		end
		if not spawn_hex then spawn_hex = { x = unit.x, y = unit.y } end
		wesnoth.wml_actions.unit {
			side = unit.side, type = type_id,
			x = spawn_hex.x, y = spawn_hex.y,
			generate_name = true, random_traits = true, moves = 0,
		}
		side.gold = side.gold - cost

	elseif poi_type == "caravan" then
		wesnoth.wml_actions.message {
			speaker = "narrator", caption = _ "Trade Caravan",
			message = _ "A merchant caravan asks for your protection. Escort them to your castle for a reward!",
			image = "units/human-peasants/ruffian.png",
		}
		local spawn_hex = nil
		for _, hex in ipairs(adjacent_hexes(unit)) do
			if not wesnoth.units.get(hex.x, hex.y) then
				local terr = wesnoth.current.map[hex]
				if terr and not tostring(terr):match("[XQ]") then
					spawn_hex = hex
					break
				end
			end
		end
		if not spawn_hex then spawn_hex = { x = unit.x, y = unit.y } end
		wesnoth.wml_actions.unit {
			side = unit.side, type = "Ruffian",
			x = spawn_hex.x, y = spawn_hex.y,
			name = _ "Trade Caravan", generate_name = false,
			canrecruit = false, upkeep = "free", max_moves = 4, moves = 0,
			wml.tag.modifications {
				wml.tag.object { wml.tag.effect { apply_to = "hitpoints", increase_total = 10 } },
			},
			wml.tag.variables { wc2x_is_caravan = true },
		}

	elseif poi_type == "shrine" then
		local buffs = {}
		for i, b in ipairs(config.shrine_buffs or {}) do
			if not buff_is_redundant(unit, b) then table.insert(buffs, b) end
		end
		if #buffs == 0 then return end
		local total_w = 0
		for _, b in ipairs(buffs) do total_w = total_w + b.weight end
		local roll = mathx.random(total_w)
		local sum = 0
		local buff
		for _, b in ipairs(buffs) do
			sum = sum + b.weight
			if roll <= sum then buff = b; break end
		end
		if not buff then buff = buffs[#buffs] end
		wesnoth.wml_actions.message {
			speaker = "narrator", caption = _ "Ancient Shrine",
			message = string.format(tostring(_ "The shrine's power flows into %s: %s!"), unit.name, buff.name),
			image = "scenery/temple1.png",
		}
		if buff.trait then
			unit:add_modification("trait", buff.trait)
		else
			unit:add_modification("object", { wml.tag.effect(buff.effect) })
		end
	end
end

-- Caravan arrival: when the caravan unit moves onto a castle/keep hex near a leader
on_event("moveto", function(cx)
	if not cx.x1 or not cx.y1 then return end
	local u = wesnoth.units.get(cx.x1, cx.y1)
	if not u or not u.variables.wc2x_is_caravan then return end

	local terrain = tostring(wesnoth.current.map[{cx.x1, cx.y1}])
	if not (terrain:match("K") or terrain:match("C")) then return end

	local nearby_leader = wesnoth.units.find_on_map({
		canrecruit = true, side = u.side,
		wml.tag.filter_location { x = cx.x1, y = cx.y1, radius = 3 },
	})[1]
	if not nearby_leader then return end

	local config = poi.config
	local side = wesnoth.sides[u.side]
	local scenario_num = wc2_scenario.scenario_num()
	local weights = config.caravan_reward_weights
	local total = weights.gold + weights.artifact + weights.training
	local roll = mathx.random(total)

	if roll <= weights.gold then
		local gold = config.caravan_gold_reward_base + (scenario_num * config.caravan_gold_reward_per_scenario)
		side.gold = side.gold + gold
		wesnoth.wml_actions.message {
			speaker = "narrator", caption = _ "Caravan Arrived!",
			message = string.format(tostring(_ "The caravan reached safety! The merchants pay you %d gold for your protection."), gold),
			image = "units/human-peasants/ruffian.png",
		}
	elseif roll <= weights.gold + weights.artifact and wc2_artifacts then
		local artifact_list = wc2_artifacts.get_artifact_list()
		if #artifact_list > 0 then
			local artifact_id = mathx.random(#artifact_list)
			wesnoth.wml_actions.message {
				speaker = "narrator", caption = _ "Caravan Arrived!",
				message = _ "The caravan reached safety! The merchants reward you with a rare artifact.",
				image = "units/human-peasants/ruffian.png",
			}
			wc2_artifacts.give_item(nearby_leader, artifact_id, true)
		else
			local gold = config.caravan_gold_reward_base + (scenario_num * config.caravan_gold_reward_per_scenario)
			side.gold = side.gold + gold
			wesnoth.wml_actions.message {
				speaker = "narrator", caption = _ "Caravan Arrived!",
				message = string.format(tostring(_ "The caravan reached safety! The merchants pay you %d gold for your protection."), gold),
				image = "units/human-peasants/ruffian.png",
			}
		end
	else
		local gave_training = false
		if wc2_training then
			local traintype, amount = wc2_training.pick_bonus(u.side)
			if traintype then
				wesnoth.wml_actions.message {
					speaker = "narrator", caption = _ "Caravan Arrived!",
					message = _ "The caravan reached safety! A traveling master among the merchants offers to train your troops.",
					image = "units/human-peasants/ruffian.png",
				}
				wc2_training.give_bonus(u.side, { x1 = cx.x1, y1 = cx.y1 }, amount, traintype)
				gave_training = true
			end
		end
		if not gave_training then
			local gold = config.caravan_gold_reward_base + (scenario_num * config.caravan_gold_reward_per_scenario)
			side.gold = side.gold + gold
			wesnoth.wml_actions.message {
				speaker = "narrator", caption = _ "Caravan Arrived!",
				message = string.format(tostring(_ "The caravan reached safety! The merchants pay you %d gold for your protection."), gold),
				image = "units/human-peasants/ruffian.png",
			}
		end
	end

	u:erase()
end)

on_event("die", function()
	if wml.variables["unit.variables.wc2x_is_caravan"] then
		wesnoth.wml_actions.message {
			speaker = "narrator", caption = _ "Caravan Lost",
			message = _ "The trade caravan has been destroyed. The merchants and their goods are lost.",
			image = "units/human-peasants/ruffian.png",
		}
	end
end)

function poi.capture_villages_for_enemies()
	local config = poi.config
	local scenario_num = wc2_scenario.scenario_num()
	local pct = math.min(
		config.enemy_village_base_pct + (scenario_num - 1) * config.enemy_village_pct_per_scenario,
		config.enemy_village_max_pct
	)
	if pct <= 0 then return end

	local player_count = wml.variables.wc2_player_count or 1
	local enemy_sides = {}
	for i = player_count + 1, #wesnoth.sides do
		local s = wesnoth.sides[i]
		if s and s.controller == "ai" and not s.variables["wc2x_is_neutral"] then
			table.insert(enemy_sides, i)
		end
	end
	if #enemy_sides == 0 then return end

	local player_keeps = {}
	for side_num = 1, player_count do
		local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
		if leader then
			table.insert(player_keeps, { x = leader.x, y = leader.y })
		end
	end

	local all_villages = wesnoth.map.find { terrain = "*^V*" }
	local capturable = {}
	for _, v in ipairs(all_villages) do
		local too_close = false
		for _, keep in ipairs(player_keeps) do
			if wesnoth.map.distance_between(v, keep) < config.enemy_village_safe_radius then
				too_close = true
				break
			end
		end
		if not too_close then
			table.insert(capturable, v)
		end
	end

	local villages_per_side = math.floor(#capturable * pct / 100 / #enemy_sides)
	if villages_per_side < 1 then return end

	local enemy_leaders = {}
	for _, side_num in ipairs(enemy_sides) do
		local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
		if leader then
			table.insert(enemy_leaders, { side = side_num, x = leader.x, y = leader.y })
		end
	end
	if #enemy_leaders == 0 then return end

	local claimed = {}
	for _, el in ipairs(enemy_leaders) do
		local dists = {}
		for i, v in ipairs(capturable) do
			if not claimed[i] then
				table.insert(dists, { idx = i, d = wesnoth.map.distance_between(v, el) })
			end
		end
		table.sort(dists, function(a, b) return a.d < b.d end)
		for j = 1, math.min(villages_per_side, #dists) do
			claimed[dists[j].idx] = true
			wesnoth.map.set_owner(capturable[dists[j].idx], el.side, false)
		end
	end
end

on_event("start", function(cx)
	poi.place_all()
	poi.capture_villages_for_enemies()
end)

return poi
