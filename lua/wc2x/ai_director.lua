-- WC3 AI Director — assigns micro AI tactics to enemy units each few turns
-- Two slots per side: one strategic (army posture) + one opportunistic (small ops)

local on_event = wesnoth.game_events.add_repeating

local director = {}
local state = {}       -- per-side tactic assignments
local dir_counter = 0  -- unique ca_id suffix

local REASSESS_INTERVAL = 3
local MAX_SPECIAL_UNITS = 5
local BODYGUARD_THRESHOLD = 3
local VILLAGE_THREAT_RADIUS = 6

local function next_ca_id()
	dir_counter = dir_counter + 1
	return "wc2x_dir_" .. dir_counter
end

local function rand_float(lo, hi)
	return lo + (mathx.random(1000) - 1) / 999 * (hi - lo)
end

-- Delete a single micro AI assignment, ignoring errors if already gone
local function delete_mai(side_num, ai_type, ca_id)
	pcall(function()
		wesnoth.wml_actions.micro_ai {
			side = side_num, ai_type = ai_type, action = "delete", ca_id = ca_id,
		}
	end)
end

local function unit_alive(uid, side_num)
	local u = wesnoth.units.find_on_map({ id = uid })[1]
	return u and u.side == side_num
end

local AMBUSH_OBJ_ID = "wc2x_granted_ambush"

local function revoke_ambush(unit_id)
	local u = wesnoth.units.find_on_map({ id = unit_id })[1]
	if u then
		pcall(function()
			wesnoth.wml_actions.remove_object { object_id = AMBUSH_OBJ_ID, wml.tag.filter { id = unit_id } }
		end)
	end
end

local function clear_slot(side_num, slot_name)
	local slot = state[side_num] and state[side_num][slot_name]
	if not slot then return end
	for i, ca_id in ipairs(slot.ca_ids) do
		delete_mai(side_num, slot.ai_types[i], ca_id)
	end
	if slot.granted_ambush_ids then
		for _, uid in ipairs(slot.granted_ambush_ids) do
			revoke_ambush(uid)
		end
	end
	state[side_num][slot_name] = nil
end

local function slot_is_stale(side_num, slot_name)
	local slot = state[side_num] and state[side_num][slot_name]
	if not slot then return true end
	if slot.forced then return false end
	for _, uid in ipairs(slot.unit_ids) do
		if unit_alive(uid, side_num) then return false end
	end
	return true
end

---------------------------------------------------------------------------
-- Situation snapshot
---------------------------------------------------------------------------
local function assess(side_num)
	local side = wesnoth.sides[side_num]
	local player_count = wml.variables.wc2_player_count or 1
	local my_units = wesnoth.units.find_on_map({ side = side_num, canrecruit = false })
	local my_leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]

	local my_villages = wesnoth.map.find {
		gives_income = true,
		wml.tag.filter_owner { side = side_num },
	}

	local total_villages = wesnoth.map.find { gives_income = true }

	local nearest_player_leader, nearest_dist = nil, math.huge
	for s = 1, player_count do
		for _, l in ipairs(wesnoth.units.find_on_map({ side = s, canrecruit = true })) do
			if my_leader then
				local d = wesnoth.map.distance_between(my_leader, l)
				if d < nearest_dist then
					nearest_dist = d
					nearest_player_leader = l
				end
			end
		end
	end

	local friendly_near_leader = 0
	if my_leader then
		for _, u in ipairs(my_units) do
			if wesnoth.map.distance_between(u, my_leader) <= 5 then
				friendly_near_leader = friendly_near_leader + 1
			end
		end
	end

	local enemies_near_my_villages = 0
	for _, v in ipairs(my_villages) do
		for s = 1, player_count do
			local threats = wesnoth.units.find_on_map({
				side = s,
				wml.tag.filter_location { x = v[1], y = v[2], radius = VILLAGE_THREAT_RADIUS },
			})
			enemies_near_my_villages = enemies_near_my_villages + #threats
		end
	end

	local assigned_ids = {}
	if state[side_num] then
		for _, slot_name in ipairs({ "strategic", "opportunistic" }) do
			local slot = state[side_num][slot_name]
			if slot then
				for _, uid in ipairs(slot.unit_ids) do
					assigned_ids[uid] = true
				end
			end
		end
	end

	return {
		side_num = side_num,
		side = side,
		gold = side.gold,
		units = my_units,
		unit_count = #my_units,
		leader = my_leader,
		villages = my_villages,
		village_count = #my_villages,
		total_village_count = #total_villages,
		nearest_player_leader = nearest_player_leader,
		nearest_player_dist = nearest_dist,
		friendly_near_leader = friendly_near_leader,
		enemies_near_villages = enemies_near_my_villages,
		aggression = tonumber(side.variables["wc2x_ai_aggression"] or "0.4"),
		caution = tonumber(side.variables["wc2x_ai_caution"] or "0.25"),
		assigned_ids = assigned_ids,
	}
end

local function available_units(sit)
	local out = {}
	for _, u in ipairs(sit.units) do
		if not sit.assigned_ids[u.id] then
			table.insert(out, u)
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Tactic definitions
---------------------------------------------------------------------------
local strategic_tactics = {}
local opportunistic_tactics = {}

-- STRATEGIC: Rally & Strike -----------------------------------------------
strategic_tactics.rally_strike = {}

function strategic_tactics.rally_strike.weight(sit)
	if not sit.leader then return 0 end
	if sit.unit_count < 4 then return 0 end
	local w = 30
	w = w + sit.aggression * 40
	w = w + math.min(sit.gold / 50, 20)
	if sit.unit_count >= 6 then w = w + 15 end
	return math.min(w, 100)
end

function strategic_tactics.rally_strike.apply(sit)
	local units = available_units(sit)
	if #units < 3 then return nil end

	mathx.shuffle(units)
	local picks = {}
	for i = 1, math.min(MAX_SPECIAL_UNITS, #units) do
		table.insert(picks, units[i])
	end

	local rally_x, rally_y = sit.leader.x, sit.leader.y
	local id_list = {}
	for _, u in ipairs(picks) do table.insert(id_list, u.id) end

	local ca_id = next_ca_id()
	wesnoth.wml_actions.micro_ai {
		side = sit.side_num,
		ai_type = "hang_out",
		action = "add",
		ca_id = ca_id,
		wml.tag.filter { id = table.concat(id_list, ",") },
		wml.tag.filter_location { x = rally_x, y = rally_y, radius = 5 },
		mobilize_on_gold_less_than = math.max(30, math.floor(sit.gold * 0.2)),
	}

	return {
		tactic = "rally_strike",
		ca_ids = { ca_id },
		ai_types = { "hang_out" },
		unit_ids = id_list,
	}
end

-- STRATEGIC: Village Turtle ------------------------------------------------
strategic_tactics.village_turtle = {}

function strategic_tactics.village_turtle.weight(sit)
	if sit.village_count == 0 then return 0 end
	if sit.enemies_near_villages == 0 then return 0 end
	local w = 20
	w = w + sit.caution * 50
	w = w + (1 - sit.aggression) * 20
	w = w + math.min(sit.enemies_near_villages * 5, 30)
	return math.min(w, 100)
end

function strategic_tactics.village_turtle.apply(sit)
	local units = available_units(sit)
	if #units == 0 then return nil end

	local threatened = {}
	local player_count = wml.variables.wc2_player_count or 1
	for _, v in ipairs(sit.villages) do
		local vx, vy = v[1], v[2]
		for s = 1, player_count do
			local threats = wesnoth.units.find_on_map({
				side = s,
				wml.tag.filter_location { x = vx, y = vy, radius = VILLAGE_THREAT_RADIUS },
			})
			if #threats > 0 then
				table.insert(threatened, { x = vx, y = vy, threats = #threats })
				break
			end
		end
	end

	if #threatened == 0 then return nil end
	table.sort(threatened, function(a, b) return a.threats > b.threats end)

	local ca_ids, ai_types, unit_ids = {}, {}, {}
	local used = {}
	for _, tv in ipairs(threatened) do
		if #unit_ids >= MAX_SPECIAL_UNITS then break end
		local best, best_dist = nil, math.huge
		for _, u in ipairs(units) do
			if not used[u.id] then
				local d = wesnoth.map.distance_between(u.x, u.y, tv.x, tv.y)
				if d < best_dist and d <= 8 then
					best = u
					best_dist = d
				end
			end
		end
		if best then
			used[best.id] = true
			local ca_id = next_ca_id()
			wesnoth.wml_actions.micro_ai {
				side = sit.side_num,
				ai_type = "stationed_guardian",
				action = "add",
				ca_id = ca_id,
				id = best.id,
				station_x = tv.x, station_y = tv.y,
				distance = 4,
				guard_x = tv.x, guard_y = tv.y,
			}
			table.insert(ca_ids, ca_id)
			table.insert(ai_types, "stationed_guardian")
			table.insert(unit_ids, best.id)
		end
	end

	if #unit_ids == 0 then return nil end
	return { tactic = "village_turtle", ca_ids = ca_ids, ai_types = ai_types, unit_ids = unit_ids }
end

-- STRATEGIC: Village Grab --------------------------------------------------
strategic_tactics.village_grab = {}

function strategic_tactics.village_grab.weight(sit)
	if not sit.leader then return 0 end
	if sit.total_village_count == 0 then return 0 end
	local fair_share = sit.total_village_count / (#wesnoth.sides - (wml.variables.wc2_player_count or 1))
	local deficit = fair_share - sit.village_count
	if deficit <= 0 then return 5 end
	local w = 20
	w = w + deficit * 15
	w = w + (1 - sit.caution) * 20
	return math.min(w, 100)
end

function strategic_tactics.village_grab.apply(sit)
	local units = available_units(sit)
	if #units == 0 or not sit.leader then return nil end

	local unowned_villages = wesnoth.map.find {
		gives_income = true,
		wml.tag.filter_owner { side = 0 },
	}
	local enemy_villages = {}
	local player_count = wml.variables.wc2_player_count or 1
	for s = 1, player_count do
		for _, v in ipairs(wesnoth.map.find { gives_income = true, wml.tag.filter_owner { side = s } }) do
			table.insert(enemy_villages, v)
		end
	end
	local targets = {}
	for _, v in ipairs(unowned_villages) do table.insert(targets, v) end
	for _, v in ipairs(enemy_villages) do table.insert(targets, v) end

	if #targets == 0 then return nil end

	table.sort(units, function(a, b) return a.max_moves > b.max_moves end)

	local ca_ids, ai_types, unit_ids = {}, {}, {}
	local claimed = {}
	for _, u in ipairs(units) do
		if #unit_ids >= math.min(3, MAX_SPECIAL_UNITS) then break end
		local best_v, best_d = nil, math.huge
		for i, v in ipairs(targets) do
			if not claimed[i] then
				local d = wesnoth.map.distance_between(u.x, u.y, v[1], v[2])
				if d < best_d then
					best_v = i
					best_d = d
				end
			end
		end
		if best_v and best_d <= 12 then
			claimed[best_v] = true
			local ca_id = next_ca_id()
			local tv = targets[best_v]
			wesnoth.wml_actions.micro_ai {
				side = sit.side_num,
				ai_type = "goto",
				action = "add",
				ca_id = ca_id,
				release_unit_at_goal = true,
				wml.tag.filter { id = u.id },
				wml.tag.filter_location { x = tv[1], y = tv[2] },
			}
			table.insert(ca_ids, ca_id)
			table.insert(ai_types, "goto")
			table.insert(unit_ids, u.id)
		end
	end

	if #unit_ids == 0 then return nil end
	return { tactic = "village_grab", ca_ids = ca_ids, ai_types = ai_types, unit_ids = unit_ids }
end

-- OPPORTUNISTIC: Raid Leader -----------------------------------------------
opportunistic_tactics.raid_leader = {}

function opportunistic_tactics.raid_leader.weight(sit)
	if not sit.nearest_player_leader then return 0 end
	if sit.unit_count < 3 then return 0 end
	local w = 10
	w = w + sit.aggression * 50
	w = w + (1 - sit.caution) * 20
	if sit.nearest_player_dist > 15 then w = w - 20 end
	return math.max(0, math.min(w, 100))
end

function opportunistic_tactics.raid_leader.apply(sit)
	local units = available_units(sit)
	if #units == 0 or not sit.nearest_player_leader then return nil end

	table.sort(units, function(a, b) return a.max_moves > b.max_moves end)
	local pick = units[1]

	local ca_id = next_ca_id()
	wesnoth.wml_actions.micro_ai {
		side = sit.side_num,
		ai_type = "assassin",
		action = "add",
		ca_id = ca_id,
		wml.tag.filter { id = pick.id },
		wml.tag.filter_second { side = sit.nearest_player_leader.side, canrecruit = true },
	}

	return {
		tactic = "raid_leader",
		ca_ids = { ca_id },
		ai_types = { "assassin" },
		unit_ids = { pick.id },
	}
end

-- OPPORTUNISTIC: Forest Ambush ---------------------------------------------
-- Finds units with ambush/submerge, places them in hiding terrain along the
-- path between enemy base and nearest player leader.
opportunistic_tactics.forest_ambush = {}

local AMBUSH_FOREST_TERRAIN = "*^F*,*^Fet*,*^Fpa*"
local MIN_AMBUSH_HEXES = 4
local MAX_DIST_TO_HIDING = 8
local AMBUSH_MIN_MOVES = 5

local function find_forest_in_corridor(enemy_leader, player_leader)
	if not enemy_leader or not player_leader then return {} end
	local base_dist = wesnoth.map.distance_between(enemy_leader, player_leader)
	local search_radius = math.min(math.floor(base_dist * 0.6), 15)
	local candidates = wesnoth.map.find {
		terrain = AMBUSH_FOREST_TERRAIN,
		wml.tag.filter_location { x = player_leader.x, y = player_leader.y, radius = search_radius },
	}
	local result = {}
	for _, hex in ipairs(candidates) do
		local d_to_enemy = wesnoth.map.distance_between(hex[1], hex[2], enemy_leader.x, enemy_leader.y)
		if d_to_enemy < base_dist then
			table.insert(result, hex)
		end
	end
	return result
end

local function find_ambush_candidates(side_num, assigned_ids, forest_hexes)
	local natural, fast = {}, {}
	local all = wesnoth.units.find_on_map({ side = side_num, canrecruit = false })
	for _, u in ipairs(all) do
		if not assigned_ids[u.id] then
			local near_forest = false
			for _, h in ipairs(forest_hexes) do
				if wesnoth.map.distance_between(u.x, u.y, h[1], h[2]) <= MAX_DIST_TO_HIDING then
					near_forest = true
					break
				end
			end
			if near_forest then
				if u:matches({ ability = "ambush" }) then
					table.insert(natural, u)
				elseif u.max_moves >= AMBUSH_MIN_MOVES then
					table.insert(fast, u)
				end
			end
		end
	end
	table.sort(fast, function(a, b) return a.max_moves > b.max_moves end)
	return natural, fast
end

local function grant_ambush(unit)
	unit:add_modification("object", {
		id = AMBUSH_OBJ_ID,
		wml.tag.effect { apply_to = "new_ability", wml.tag.abilities {
			wml.tag.hides { id = "wc2x_ambush_granted", name = "ambush",
				description = "This unit can hide in forest, and remain undetected by its enemies.",
				wml.tag.filter_self { wml.tag.filter_location { terrain = "*^F*" } },
			},
		}},
	})
end

local function nearest_hex_to_target(hexes, tx, ty)
	local best, best_d = nil, math.huge
	for _, h in ipairs(hexes) do
		local d = wesnoth.map.distance_between(h[1], h[2], tx, ty)
		if d < best_d then best, best_d = h, d end
	end
	return best
end

function opportunistic_tactics.forest_ambush.weight(sit)
	if sit.unit_count < 3 then return 0 end
	if not sit.leader or not sit.nearest_player_leader then return 0 end
	local forest_hexes = find_forest_in_corridor(sit.leader, sit.nearest_player_leader)
	if #forest_hexes < MIN_AMBUSH_HEXES then return 0 end
	local natural, fast = find_ambush_candidates(sit.side_num, sit.assigned_ids, forest_hexes)
	local usable = #natural + math.min(#fast, 3)
	if usable == 0 then return 0 end
	local w = 15
	w = w + sit.caution * 30
	w = w + math.min(usable, 3) * 10
	if #natural > 0 then w = w + 10 end
	return math.min(w, 100)
end

function opportunistic_tactics.forest_ambush.apply(sit)
	local forest_hexes = find_forest_in_corridor(sit.leader, sit.nearest_player_leader)
	if #forest_hexes < MIN_AMBUSH_HEXES then return nil end

	local natural, fast = find_ambush_candidates(sit.side_num, sit.assigned_ids, forest_hexes)
	local picks = {}
	local granted_ids = {}
	for i = 1, math.min(3, #natural) do
		table.insert(picks, natural[i])
	end
	local remaining = 3 - #picks
	for i = 1, math.min(remaining, #fast) do
		local u = fast[i]
		grant_ambush(u)
		table.insert(granted_ids, u.id)
		table.insert(picks, u)
	end

	if #picks == 0 then return nil end

	local px, py = sit.nearest_player_leader.x, sit.nearest_player_leader.y
	local ca_ids, ai_types, unit_ids = {}, {}, {}
	local used_goals = {}

	for _, u in ipairs(picks) do
		local goal = nearest_hex_to_target(forest_hexes, px, py)
		if goal then
			local gkey = goal[1] .. "," .. goal[2]
			if used_goals[gkey] then
				local alt_hexes = {}
				for _, h in ipairs(forest_hexes) do
					if h[1] .. "," .. h[2] ~= gkey then table.insert(alt_hexes, h) end
				end
				if #alt_hexes > 0 then goal = nearest_hex_to_target(alt_hexes, px, py) end
			end
			if goal then
				used_goals[goal[1] .. "," .. goal[2]] = true
				local ca_id = next_ca_id()
				wesnoth.wml_actions.micro_ai {
					side = sit.side_num,
					ai_type = "goto",
					action = "add",
					ca_id = ca_id,
					release_unit_at_goal = true,
					wml.tag.filter { id = u.id },
					wml.tag.filter_location { x = goal[1], y = goal[2] },
				}
				table.insert(ca_ids, ca_id)
				table.insert(ai_types, "goto")
				table.insert(unit_ids, u.id)
			end
		end
	end

	if #unit_ids == 0 then
		for _, uid in ipairs(granted_ids) do revoke_ambush(uid) end
		return nil
	end
	return {
		tactic = "forest_ambush",
		ca_ids = ca_ids,
		ai_types = ai_types,
		unit_ids = unit_ids,
		granted_ambush_ids = granted_ids,
	}
end

-- OPPORTUNISTIC: Leader Bodyguard ------------------------------------------
opportunistic_tactics.leader_bodyguard = {}

function opportunistic_tactics.leader_bodyguard.weight(sit)
	if not sit.leader then return 0 end
	if sit.friendly_near_leader >= BODYGUARD_THRESHOLD then return 0 end
	local w = 30
	w = w + sit.caution * 30
	w = w + (BODYGUARD_THRESHOLD - sit.friendly_near_leader) * 15
	return math.min(w, 100)
end

function opportunistic_tactics.leader_bodyguard.apply(sit)
	local units = available_units(sit)
	if #units == 0 or not sit.leader then return nil end

	table.sort(units, function(a, b) return a.max_hitpoints > b.max_hitpoints end)

	local count = math.min(2, #units)
	local ca_ids, ai_types, unit_ids = {}, {}, {}
	for i = 1, count do
		local u = units[i]
		local ca_id = next_ca_id()
		wesnoth.wml_actions.micro_ai {
			side = sit.side_num,
			ai_type = "stationed_guardian",
			action = "add",
			ca_id = ca_id,
			id = u.id,
			station_x = sit.leader.x, station_y = sit.leader.y,
			distance = 5,
			guard_x = sit.leader.x, guard_y = sit.leader.y,
		}
		table.insert(ca_ids, ca_id)
		table.insert(ai_types, "stationed_guardian")
		table.insert(unit_ids, u.id)
	end

	return { tactic = "leader_bodyguard", ca_ids = ca_ids, ai_types = ai_types, unit_ids = unit_ids }
end

---------------------------------------------------------------------------
-- Weighted pick — returns tactic name
---------------------------------------------------------------------------
local function weighted_pick(tactics_table, sit)
	local weights = {}
	local total = 0
	for name, tactic in pairs(tactics_table) do
		local w = tactic.weight(sit)
		if w > 0 then
			table.insert(weights, { name = name, w = w })
			total = total + w
		end
	end
	if total == 0 then return nil end
	table.sort(weights, function(a, b) return a.name < b.name end)

	local roll = rand_float(0, total)
	local cumulative = 0
	for _, entry in ipairs(weights) do
		cumulative = cumulative + entry.w
		if roll <= cumulative then return entry.name end
	end
	return weights[#weights].name
end

---------------------------------------------------------------------------
-- Adjust recruitment save-gold thresholds based on active strategic tactic
---------------------------------------------------------------------------
local function update_spend_rate(side_num)
	local cfg = director.config
	if not cfg or not cfg.ai_tactic_spend_modifier then return end

	local side = wesnoth.sides[side_num]
	local base_begin = tonumber(side.variables["wc2x_ai_save_begin"]) or 1.5
	local base_end = tonumber(side.variables["wc2x_ai_save_end"]) or 1.1

	local tactic_name = state[side_num] and state[side_num].strategic and state[side_num].strategic.tactic
	local modifier = cfg.ai_tactic_spend_modifier[tactic_name] or 1.0

	local new_begin = base_begin * modifier

	wesnoth.wml_actions.modify_side {
		side = side_num,
		wml.tag.ai {
			wml.tag.recruitment_save_gold {
				begin = new_begin,
				["end"] = base_end,
			},
		},
	}
end

---------------------------------------------------------------------------
-- Main reassess loop
---------------------------------------------------------------------------
local function reassess(side_num)
	if not state[side_num] then state[side_num] = {} end

	local sit = assess(side_num)
	if not sit.leader then return end
	if sit.unit_count < 2 then return end

	if slot_is_stale(side_num, "strategic") then
		clear_slot(side_num, "strategic")
	end
	if slot_is_stale(side_num, "opportunistic") then
		clear_slot(side_num, "opportunistic")
	end

	if not state[side_num].strategic then
		local name = weighted_pick(strategic_tactics, sit)
		if name then
			local result = strategic_tactics[name].apply(sit)
			if result then
				state[side_num].strategic = result
				for _, uid in ipairs(result.unit_ids) do
					sit.assigned_ids[uid] = true
				end
			end
		end
	end

	update_spend_rate(side_num)

	if not state[side_num].opportunistic then
		local name = weighted_pick(opportunistic_tactics, sit)
		if name then
			local result = opportunistic_tactics[name].apply(sit)
			if result then
				state[side_num].opportunistic = result
			end
		end
	end
end

---------------------------------------------------------------------------
-- Cleanup dead units' micro AIs (runs every turn, not just reassess turns)
---------------------------------------------------------------------------
local function cleanup_dead(side_num)
	if not state[side_num] then return end
	for _, slot_name in ipairs({ "strategic", "opportunistic" }) do
		local slot = state[side_num][slot_name]
		if slot then
			local any_alive = false
			for _, uid in ipairs(slot.unit_ids) do
				if unit_alive(uid, side_num) then
					any_alive = true
					break
				end
			end
			if not any_alive then
				clear_slot(side_num, slot_name)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Init — hook into side turn events
---------------------------------------------------------------------------
function director.init(config)
	director.config = config

	on_event("side turn", function()
		local side_num = wesnoth.current.side
		if wc2_scenario.is_human_side(side_num) then return end
		local side = wesnoth.sides[side_num]
		if side.controller ~= "ai" then return end

		cleanup_dead(side_num)

		if wesnoth.current.turn % REASSESS_INTERVAL == 1 or wesnoth.current.turn == 1 then
			reassess(side_num)
		end
	end)

	director.register_debug_commands()
end

---------------------------------------------------------------------------
-- Debug: chat commands
---------------------------------------------------------------------------
local show_labels = false
local debug_overlay_units = {}

local function msg(text)
	wesnoth.wml_actions.chat { speaker = "WC3 Debug", message = text }
end

local PERSONALITY_KEYS = {
	"wc2x_ai_aggression", "wc2x_ai_caution", "wc2x_ai_village_value",
	"wc2x_ai_villages_per_scout", "wc2x_ai_leader_aggression",
	"wc2x_ai_scout_village_targeting", "wc2x_ai_grouping",
	"wc2x_ai_save_begin", "wc2x_ai_save_end",
	"wc2x_ai_recruit_diversity", "wc2x_ai_recruit_randomness",
}
local PERSONALITY_LABELS = {
	"aggression", "caution", "village_value",
	"villages_per_scout", "leader_aggression",
	"scout_village_targeting", "grouping",
	"save_begin", "save_end",
	"recruit_diversity", "recruit_randomness",
}

local function print_personality(side_num)
	local side = wesnoth.sides[side_num]
	local parts = {}
	for i, key in ipairs(PERSONALITY_KEYS) do
		local val = side.variables[key]
		if val then
			table.insert(parts, PERSONALITY_LABELS[i] .. "=" .. tostring(val))
		end
	end
	if #parts == 0 then
		msg(string.format("Side %d: no personality data", side_num))
	else
		msg(string.format("Side %d personality: %s", side_num, table.concat(parts, ", ")))
	end
end

local function print_tactics(side_num)
	local s = state[side_num]
	if not s then
		msg(string.format("Side %d: no active tactics", side_num))
		return
	end
	for _, slot_name in ipairs({ "strategic", "opportunistic" }) do
		local slot = s[slot_name]
		if slot then
			local alive = 0
			for _, uid in ipairs(slot.unit_ids) do
				if unit_alive(uid, side_num) then alive = alive + 1 end
			end
			msg(string.format("  Side %d [%s]: %s — %d/%d units alive — units: %s",
				side_num, slot_name, slot.tactic, alive, #slot.unit_ids,
				table.concat(slot.unit_ids, ", ")))
		else
			msg(string.format("  Side %d [%s]: (empty)", side_num, slot_name))
		end
	end
end

local function print_weights(side_num)
	local sit = assess(side_num)
	if not sit.leader then
		msg(string.format("Side %d: no leader, can't assess", side_num))
		return
	end
	msg(string.format("Side %d situation: %d gold, %d units, %d/%d villages, nearest player %d hexes",
		side_num, sit.gold, sit.unit_count, sit.village_count, sit.total_village_count,
		sit.nearest_player_dist == math.huge and -1 or sit.nearest_player_dist))
	msg("  Strategic weights:")
	for name, tactic in pairs(strategic_tactics) do
		msg(string.format("    %s: %.0f", name, tactic.weight(sit)))
	end
	msg("  Opportunistic weights:")
	for name, tactic in pairs(opportunistic_tactics) do
		msg(string.format("    %s: %.0f", name, tactic.weight(sit)))
	end
end

local function force_tactic(side_num, slot_name, tactic_name)
	local pool = slot_name == "strategic" and strategic_tactics or opportunistic_tactics
	local tactic = pool[tactic_name]
	if not tactic then
		msg("Unknown tactic: " .. tactic_name)
		return
	end
	clear_slot(side_num, slot_name)
	if not state[side_num] then state[side_num] = {} end
	local sit = assess(side_num)
	if not sit.leader then
		msg("Side " .. side_num .. " has no leader")
		return
	end
	local result = tactic.apply(sit)
	if result then
		result.forced = true
		state[side_num][slot_name] = result
		msg(string.format("Forced side %d %s → %s (%d units) [locked until dead]", side_num, slot_name, tactic_name, #result.unit_ids))
	else
		msg("Tactic " .. tactic_name .. " returned nil (no eligible units?)")
	end
end

local TACTIC_OVERLAYS = {
	rally_strike    = "misc/hero-icon.png",
	village_turtle  = "misc/loyal-icon.png",
	village_grab    = "items/gold-coins-small.png",
	raid_leader     = "misc/red-x.png",
	forest_ambush   = "misc/vision-fog.png",
	leader_bodyguard = "misc/leader-expendable.png",
}

local DEBUG_OVERLAY_ID = "wc2x_debug_tactic_overlay"

local function clear_debug_overlays()
	for uid, overlay in pairs(debug_overlay_units) do
		local u = wesnoth.units.find_on_map({ id = uid })[1]
		if u then
			u:add_modification("object", {
				id = DEBUG_OVERLAY_ID .. "_remove",
				wml.tag.effect { apply_to = "overlay", remove = overlay },
			})
		end
	end
	debug_overlay_units = {}
end

local function apply_debug_overlays(side_num)
	local s = state[side_num]
	if not s then return end
	for _, slot_name in ipairs({ "strategic", "opportunistic" }) do
		local slot = s[slot_name]
		if slot and slot.unit_ids then
			local overlay = TACTIC_OVERLAYS[slot.tactic]
			if overlay then
				for _, uid in ipairs(slot.unit_ids) do
					local u = wesnoth.units.find_on_map({ id = uid })[1]
					if u then
						debug_overlay_units[uid] = overlay
						u:add_modification("object", {
							id = DEBUG_OVERLAY_ID,
							wml.tag.effect { apply_to = "overlay", add = overlay },
						})
						wesnoth.interface.float_label(u.x, u.y, slot.tactic)
					end
				end
			end
		end
	end
end

local function update_labels()
	local player_count = wml.variables.wc2_player_count or 1
	for i = player_count + 1, #wesnoth.sides do
		local side = wesnoth.sides[i]
		if side.controller == "ai" then
			local leader = wesnoth.units.find_on_map({ side = i, canrecruit = true })[1]
			if leader then
				if show_labels then
					local s = state[i]
					local strat = s and s.strategic and s.strategic.tactic or "-"
					local opp = s and s.opportunistic and s.opportunistic.tactic or "-"
					wesnoth.interface.float_label(leader.x, leader.y,
						string.format("S:%s O:%s", strat, opp))
				end
			end
		end
	end
end

function director.register_debug_commands()
	on_event("side turn", function()
		if show_labels then update_labels() end
	end)
end

---------------------------------------------------------------------------
-- Debug API — call from Lua console  :lua wc2x.debug.tactics()
---------------------------------------------------------------------------
director.debug = {}

function director.debug.tactics(side_num)
	clear_debug_overlays()
	if side_num then
		print_tactics(side_num)
		print_weights(side_num)
		apply_debug_overlays(side_num)
	else
		local player_count = wml.variables.wc2_player_count or 1
		for i = player_count + 1, #wesnoth.sides do
			if wesnoth.sides[i].controller == "ai" then
				print_tactics(i)
				apply_debug_overlays(i)
			end
		end
	end
	msg("Unit overlays applied — run wc2x.debug.clear() to remove them")
end

function director.debug.clear()
	clear_debug_overlays()
	msg("Debug overlays cleared")
end

function director.debug.personality(side_num)
	if side_num then
		print_personality(side_num)
	else
		local player_count = wml.variables.wc2_player_count or 1
		for i = player_count + 1, #wesnoth.sides do
			if wesnoth.sides[i].controller == "ai" then
				print_personality(i)
			end
		end
	end
end

function director.debug.weights(side_num)
	if side_num then
		print_weights(side_num)
	else
		local player_count = wml.variables.wc2_player_count or 1
		for i = player_count + 1, #wesnoth.sides do
			if wesnoth.sides[i].controller == "ai" then
				print_weights(i)
			end
		end
	end
end

function director.debug.force(side_num, slot_name, tactic_name)
	if not side_num or not slot_name or not tactic_name then
		msg("Usage: wc2x.debug.force(side, 'strategic'|'opportunistic', 'tactic_name')")
		return
	end
	force_tactic(side_num, slot_name, tactic_name)
end

function director.debug.labels(on)
	if on == nil then on = not show_labels end
	show_labels = on
	if show_labels then
		update_labels()
		msg("Tactic labels ON")
	else
		msg("Tactic labels OFF")
	end
end

function director.debug.help()
	msg("WC3 AI Director debug commands (use :lua prefix):")
	msg("  wc2x.debug.tactics()       — all sides' active tactics")
	msg("  wc2x.debug.tactics(4)      — side 4 tactics + weights")
	msg("  wc2x.debug.personality()   — all sides' AI personality values")
	msg("  wc2x.debug.personality(4)  — side 4 personality")
	msg("  wc2x.debug.weights(4)      — side 4 situation + all tactic weights")
	msg("  wc2x.debug.force(4,'strategic','rally_strike')  — force tactic")
	msg("  wc2x.debug.labels()        — toggle floating labels on/off")
	msg("  wc2x.debug.labels(true)    — labels on")
	msg("  wc2x.debug.clear()         — remove debug overlays from units")
	msg("  wc2x.debug.help()          — this message")
end

return director
