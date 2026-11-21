-- Dawnbreakers: from config.dawnbreakers_start_pct of the map's turn limit, every
-- config.dawnbreakers_interval turns,
-- near-legendary enemy units march in from the map edge to rescue the enemy side that is losing
-- worst (fewest villages): leader-level units from that faction's leader list with the
-- "dawnbreaker" trait and legendary affixes, but no artifact drop. They give leader-level XP but
-- cost far more to beat, so stalling a won map is a fight, not a farm. The wave grows with how
-- much of the map the players hold. Replaced hardened reinforcements (0.17.0).

local _ = wesnoth.textdomain 'wesnoth-wc'
local on_event = wesnoth.game_events.add_repeating

local dawnbreakers = {}

local function is_enemy_side(side_num)
	if wc2_scenario.is_human_side(side_num) then return false end
	if wesnoth.sides[side_num].variables["wc2x_is_neutral"] then return false end
	return side_num ~= wml.variables["wc2x_boss_side"]
end

local function human_sides()
	local res = {}
	for _i, side in ipairs(wesnoth.sides) do
		if wc2_scenario.is_human_side(side.side) then table.insert(res, side.side) end
	end
	return res
end

-- % of the map's villages held by players (whole number, so every client agrees)
function dawnbreakers.player_village_pct()
	local total = #wesnoth.map.find { gives_income = true }
	if total == 0 then return 0 end
	local held = 0
	for _i, s in ipairs(human_sides()) do held = held + wesnoth.sides[s].num_villages end
	return held * 100 // total
end

-- the enemy side with a living leader and the fewest villages; ties go to the lowest side number
local function pick_rescued_side()
	local best
	for _i, side in ipairs(wesnoth.sides) do
		if is_enemy_side(side.side) and wesnoth.units.find_on_map({ side = side.side, canrecruit = true })[1]
			and #side.recruit > 0 and (not best or side.num_villages < best.num_villages) then
			best = side
		end
	end
	return best
end

-- the first tier whose max_pct is above the players' village share
local function pick_tier(pct)
	for _i, tier in ipairs(wc2x.config.dawnbreakers_tiers) do
		if pct < tier.max_pct then return tier end
	end
	return wc2x.config.dawnbreakers_tiers[#wc2x.config.dawnbreakers_tiers]
end

function dawnbreakers.trait()
	local config = wc2x.config
	return {
		id = "wc2x_dawnbreaker", male_name = _ "dawnbreaker", female_name = _ "female^dawnbreaker",
		description = string.format(tostring(
			_ "One of the Dawnbreakers, sent to rescue a losing side: +%s hitpoints, +%s damage on all attacks, +%d moves, no upkeep."),
			config.dawnbreakers_hp_bonus, config.dawnbreakers_damage_bonus, config.legendary_moves),
		wml.tag.effect { apply_to = "hitpoints", increase_total = config.dawnbreakers_hp_bonus },
		wml.tag.effect { apply_to = "attack", increase_damage = config.dawnbreakers_damage_bonus },
		wml.tag.effect { apply_to = "movement", increase = config.legendary_moves },
		wml.tag.effect { apply_to = "loyal" },
	}
end

-- free edge hexes hidden from every player, nearest the rescued side's leader first; visible ones
-- only if no hidden one is left
local function edge_hexes(side_num, leader)
	local map = wesnoth.current.map
	-- the first edge is a plain key, not an [or]: an [or] in an otherwise empty filter would be
	-- ORed with "every hex"
	local edge = wml.tag["and"] {
		x = 1,
		wml.tag["or"] { x = map.playable_width },
		wml.tag["or"] { y = 1 }, wml.tag["or"] { y = map.playable_height },
	}
	local function find(hidden)
		local filter = { edge, wml.tag["not"] { wml.tag.filter {} } }
		if hidden then
			table.insert(filter, wml.tag.filter_vision {
				side = table.concat(human_sides(), ","), visible = false,
			})
		end
		local hexes = wesnoth.map.find(filter)
		table.sort(hexes, function(a, b)
			local da = wesnoth.map.distance_between(a, leader)
			local db = wesnoth.map.distance_between(b, leader)
			if da ~= db then return da < db end
			if a.x ~= b.x then return a.x < b.x end
			return a.y < b.y
		end)
		return hexes
	end
	local hexes = find(true)
	for _i, hex in ipairs(find(false)) do table.insert(hexes, hex) end
	return hexes
end

-- `count` unit types at this map's enemy leader level: drawn (with repeats) from the rescued
-- faction's WC2 leader list, resolved like its leader (enemy.resolve_leader_type). The list is read,
-- not consumed (WC2's own pick removes entries). Falls back to the shared unit pool at that level,
-- rolled on one machine (unit_pool.synced_sample), when the faction is unknown.
local function leader_types(side, count)
	local scenario = wc2_scenario.scenario_num()
	local group_id = side.variables["wc2x_enemy_group"]
	local leaders = group_id and wml.array_access.get(("wc2_enemy_army.group[%d].leader"):format(group_id)) or {}
	local types = {}
	if #leaders > 0 then
		for _i = 1, count do
			local t = wc2_enemy.resolve_leader_type(leaders[mathx.random(#leaders)], scenario)
			if t and wesnoth.unit_types[t] then table.insert(types, t) end
		end
	end
	if #types == 0 and wc2x.unit_pool then
		local level = wc2_enemy.get_target_leader_level(scenario)
		local ids = wc2x.unit_pool.synced_sample(level, level, count)
		for _i, t in ipairs(ids) do table.insert(types, t) end
	end
	return types
end

local function spawn_wave()
	local side = pick_rescued_side()
	if not side then return end
	local leader = wesnoth.units.find_on_map({ side = side.side, canrecruit = true })[1]
	local pct = dawnbreakers.player_village_pct()
	local tier = pick_tier(pct)
	local count = tier.count
	local types = leader_types(side, count)
	if #types == 0 then return end

	local hexes = edge_hexes(side.side, leader)
	local used = {}
	local spawned = 0
	for _n = 1, #types do
		local u = wesnoth.units.create {
			type = types[_n], side = side.side, generate_name = true,
		}
		u:add_modification("trait", dawnbreakers.trait())
		wc2x.legendary.roll_affixes(u, tier.affixes)
		u.hitpoints = u.max_hitpoints
		u.variables.wc2x_dawnbreaker = true
		local spot
		for _i, hex in ipairs(hexes) do
			local key = hex.x .. "," .. hex.y
			if not used[key] and wesnoth.units.movement_on(u, wesnoth.current.map[hex]) <= u.max_moves then
				used[key] = true
				spot = hex
				break
			end
		end
		if spot and #wesnoth.units.find_on_map { x = spot.x, y = spot.y } == 0 then
			u:to_map(spot.x, spot.y)
			wesnoth.interface.float_label(spot.x, spot.y, _ "Dawnbreakers!", "255,140,0")
			spawned = spawned + 1
		end
	end
	if spawned > 0 then
		local msg
		if spawned == 1 then
			msg = string.format(tostring(
				_ "A Dawnbreaker marches in from the map edge to rescue side %d."),
				side.side)
		else
			msg = string.format(tostring(
				_ "%d Dawnbreakers march in from the map edge to rescue side %d."),
				spawned, side.side)
		end
		wesnoth.interface.add_chat_message("WC3", msg)
	end
end

-- first wave: config.dawnbreakers_start_pct of the turn limit, rounded up (whole numbers, so
-- every client agrees)
function dawnbreakers.start_turn()
	return math.max(1, (wesnoth.scenario.turns * wc2x.config.dawnbreakers_start_pct + 99) // 100)
end

function dawnbreakers.init()
	on_event("new turn", function()
		local config = wc2x.config
		local t = wesnoth.current.turn - dawnbreakers.start_turn()
		if t < 0 or t % config.dawnbreakers_interval ~= 0 then return end
		spawn_wave()
	end)
end

return dawnbreakers
