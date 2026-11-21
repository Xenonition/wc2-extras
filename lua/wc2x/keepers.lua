-- Keepers: from config.keepers_start_turn, every config.keepers_interval turns a few enemy
-- units march in from the map edge to rescue the enemy side that is losing worst (fewest
-- villages). They are that side's ordinary recruits made tougher by the "keeper" trait and one
-- or two legendary affixes, at their normal level, so they give ordinary kill XP for a much
-- harder fight: stalling a won map gets more dangerous without becoming an XP farm. The wave
-- grows with how much of the map the players hold. Replaced hardened reinforcements (0.17.0).

local _ = wesnoth.textdomain 'wesnoth-wc'
local on_event = wesnoth.game_events.add_repeating

local keepers = {}

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
function keepers.player_village_pct()
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
	for _i, tier in ipairs(wc2x.config.keepers_tiers) do
		if pct < tier.max_pct then return tier end
	end
	return wc2x.config.keepers_tiers[#wc2x.config.keepers_tiers]
end

function keepers.trait()
	local config = wc2x.config
	return {
		id = "wc2x_keeper", male_name = _ "keeper", female_name = _ "female^keeper",
		description = string.format(tostring(
			_ "One of the Keepers, sent to rescue a losing side: +%s hitpoints, +%s damage on all attacks, no upkeep."),
			config.keepers_hp_bonus, config.keepers_damage_bonus),
		wml.tag.effect { apply_to = "hitpoints", increase_total = config.keepers_hp_bonus },
		wml.tag.effect { apply_to = "attack", increase_damage = config.keepers_damage_bonus },
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

local function spawn_wave()
	local side = pick_rescued_side()
	if not side then return end
	local leader = wesnoth.units.find_on_map({ side = side.side, canrecruit = true })[1]
	local pct = keepers.player_village_pct()
	local tier = pick_tier(pct)
	local count = tier.base + wc2_scenario.scenario_num() * tier.per_scenario

	local types = {}
	for _i, t in ipairs(side.recruit) do table.insert(types, t) end
	table.sort(types)

	local hexes = edge_hexes(side.side, leader)
	local used = {}
	local spawned = 0
	for _n = 1, count do
		local u = wesnoth.units.create {
			type = types[mathx.random(#types)], side = side.side, generate_name = true,
		}
		u:add_modification("trait", keepers.trait())
		wc2x.legendary.roll_affixes(u, tier.affixes)
		u.hitpoints = u.max_hitpoints
		u.variables.wc2x_keeper = true
		local spot
		for _i, hex in ipairs(hexes) do
			local key = hex.x .. "," .. hex.y
			if not used[key] and wesnoth.units.movement_on(u, wesnoth.current.map[hex]) <= u.max_moves then
				used[key] = true
				spot = hex
				break
			end
		end
		if spot then
			u:to_map(spot.x, spot.y)
			wesnoth.interface.float_label(spot.x, spot.y, _ "Keepers!", "255,140,0")
			spawned = spawned + 1
		end
	end
	if spawned > 0 then
		local msg
		if spawned == 1 then
			msg = string.format(tostring(
				_ "A Keeper marches in from the map edge to rescue side %d (players hold %d%% of the villages)."),
				side.side, pct)
		else
			msg = string.format(tostring(
				_ "%d Keepers march in from the map edge to rescue side %d (players hold %d%% of the villages)."),
				spawned, side.side, pct)
		end
		wesnoth.interface.add_chat_message("WC3", msg)
	end
end

function keepers.init()
	on_event("new turn", function()
		local config = wc2x.config
		local t = wesnoth.current.turn - config.keepers_start_turn
		if t < 0 or t % config.keepers_interval ~= 0 then return end
		spawn_wave()
	end)
end

return keepers
