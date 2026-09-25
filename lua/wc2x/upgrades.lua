-- WC2 Extras — persistent upgrades
-- State stored in side variables (wc2x_upgrades.*), persists via savegame.
-- Fortification hex positions are placed each scenario and mirrored into side variables
-- so they survive save/load and MP rejoin.

local _ = wesnoth.textdomain 'wesnoth-wc'
local on_event = wesnoth.game_events.add_repeating

local upgrades = {}

-- Per-scenario fortification locations: { [side_num] = { barracks = {{x,y},...}, training = {{x,y},...} } }
local fortifications = {}

local function encode_locs(locs)
	local parts = {}
	for i, loc in ipairs(locs) do parts[i] = loc.x .. "," .. loc.y end
	return table.concat(parts, ";")
end

local function decode_locs(str)
	local locs = {}
	for x, y in (str or ""):gmatch("(%d+),(%d+)") do
		table.insert(locs, { x = tonumber(x), y = tonumber(y) })
	end
	return locs
end

local function persist_side(side_num)
	local vars = wesnoth.sides[side_num].variables
	local forts = fortifications[side_num] or { barracks = {}, training = {} }
	vars["wc2x_forts_barracks"] = encode_locs(forts.barracks)
	vars["wc2x_forts_training"] = encode_locs(forts.training)
	vars["wc2x_pending_reinf"] = (upgrades.pending_reinforcements or {})[side_num] or 0
end

-- Save files and rejoining MP clients get a fresh Lua state; rebuild it from side variables
on_event("preload", function()
	fortifications = {}
	upgrades.pending_reinforcements = nil
	for side_num = 1, (wml.variables.wc2_player_count or 1) do
		local vars = wesnoth.sides[side_num] and wesnoth.sides[side_num].variables
		if vars then
			fortifications[side_num] = {
				barracks = decode_locs(vars["wc2x_forts_barracks"]),
				training = decode_locs(vars["wc2x_forts_training"]),
			}
			local reinf = vars["wc2x_pending_reinf"] or 0
			if reinf > 0 then
				upgrades.pending_reinforcements = upgrades.pending_reinforcements or {}
				upgrades.pending_reinforcements[side_num] = reinf
			end
		end
	end
end)

function upgrades.init(config)
	upgrades.config = config
end

function upgrades.get_count(side_num, upgrade_id)
	local side = wesnoth.sides[side_num]
	return side.variables["wc2x_upgrades." .. upgrade_id] or 0
end

function upgrades.purchase(side_num, upgrade_id)
	local side = wesnoth.sides[side_num]
	local key = "wc2x_upgrades." .. upgrade_id
	side.variables[key] = (side.variables[key] or 0) + 1
end

function upgrades.get_price(side_num, upgrade_id)
	local count = upgrades.get_count(side_num, upgrade_id)
	local base = upgrades.config.upgrade_prices[upgrade_id]
	if not base then return 999999 end
	return math.ceil(base * (upgrades.config.upgrade_price_escalation ^ count))
end

function upgrades.apply_for_side(side_num)
	local side = wesnoth.sides[side_num]

	local income_count = upgrades.get_count(side_num, "base_income")
	if income_count > 0 then
		wesnoth.wml_actions.modify_side {
			side = side_num,
			income = income_count * 3,
		}
	end

	local vision_count = upgrades.get_count(side_num, "vision_radius")
	if vision_count > 0 then
		local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
		if leader then
			wesnoth.wml_actions.lift_fog {
				wml.tag.filter_side { side = side_num },
				x = leader.x, y = leader.y,
				radius = vision_count * 3,
				multiturn = true,
			}
		end
	end

	local reinf_count = upgrades.get_count(side_num, "reinforcements")
	if reinf_count > 0 then
		upgrades.pending_reinforcements = upgrades.pending_reinforcements or {}
		upgrades.pending_reinforcements[side_num] = reinf_count
	end
end

function upgrades.apply_castle_hexes(side_num)
	fortifications[side_num] = { barracks = {}, training = {} }

	local castle_count = upgrades.get_count(side_num, "castle_hex")
	local supply_count = upgrades.get_count(side_num, "supply_village")
	local barracks_count = upgrades.get_count(side_num, "barracks")
	local training_count = upgrades.get_count(side_num, "training_ground")

	if castle_count + supply_count + barracks_count + training_count == 0 then
		return
	end

	local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
	if not leader then return end

	local castle_hexes = wesnoth.map.find {
		terrain = "C*,K*,*^C*,*^K*",
		wml.tag["and"] {
			x = leader.x, y = leader.y,
			radius = 999,
			wml.tag.filter_radius { terrain = "C*,K*,*^C*,*^K*" },
		},
	}

	local expansion_candidates = {}
	local seen = {}
	for _, hex in ipairs(castle_hexes) do
		local adj_list = { wesnoth.map.get_adjacent_hexes(hex) }
		for _, adj in ipairs(adj_list) do
			local terrain = wesnoth.current.map[adj]
			if terrain and not tostring(terrain):match("[CK]") then
				local coord_key = adj.x .. "," .. adj.y
				if not seen[coord_key] then
					seen[coord_key] = true
					table.insert(expansion_candidates, adj)
				end
			end
		end
	end

	mathx.shuffle(expansion_candidates)
	local placed = 0

	for i = 1, supply_count do
		if placed >= #expansion_candidates then break end
		placed = placed + 1
		local loc = expansion_candidates[placed]
		wesnoth.current.map[loc] = "Ch^Vov"
		wesnoth.map.set_owner(loc, side_num, false)
		wesnoth.wml_actions.item {
			x = loc.x, y = loc.y,
			image = "scenery/well.png",
			z_order = -5,
		}
		wesnoth.wml_actions.label { x = loc.x, y = loc.y, text = _ "Supply" }
	end

	for i = 1, barracks_count do
		if placed >= #expansion_candidates then break end
		placed = placed + 1
		local loc = expansion_candidates[placed]
		wesnoth.current.map[loc] = "Ch"
		table.insert(fortifications[side_num].barracks, { x = loc.x, y = loc.y })
		wesnoth.wml_actions.item {
			x = loc.x, y = loc.y,
			image = "scenery/tent-shop-weapons.png",
			z_order = -5,
		}
		wesnoth.wml_actions.label { x = loc.x, y = loc.y, text = _ "Barracks" }
	end

	for i = 1, training_count do
		if placed >= #expansion_candidates then break end
		placed = placed + 1
		local loc = expansion_candidates[placed]
		wesnoth.current.map[loc] = "Ch"
		table.insert(fortifications[side_num].training, { x = loc.x, y = loc.y })
		wesnoth.wml_actions.item {
			x = loc.x, y = loc.y,
			image = "items/dummy.png",
			z_order = -5,
		}
		wesnoth.wml_actions.label { x = loc.x, y = loc.y, text = _ "Training" }
	end

	for i = 1, castle_count do
		if placed >= #expansion_candidates then break end
		placed = placed + 1
		wesnoth.current.map[expansion_candidates[placed]] = "Ch"
	end
end

-- Apply at scenario start
on_event("wc2_start", function(cx)
	fortifications = {}
	upgrades.pending_reinforcements = {}
	for side_num = 1, (wml.variables.wc2_player_count or 1) do
		upgrades.apply_castle_hexes(side_num)
		upgrades.apply_for_side(side_num)
		upgrades.place_pending_artifacts(side_num)
		persist_side(side_num)
	end
end)

function upgrades.place_pending_artifacts(side_num)
	local side = wesnoth.sides[side_num]
	local pending_str = side.variables["wc2x_pending_artifacts"] or ""
	if pending_str == "" then return end

	local artifact_ids = stringx.split(pending_str)
	side.variables["wc2x_pending_artifacts"] = ""

	if not wc2_artifacts then return end

	local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
	if not leader then return end

	local taken = {}
	for _, id_str in ipairs(artifact_ids) do
		local artifact_id = tonumber(id_str)
		if artifact_id then
			local hex = wc2x.placement.item_hex(leader, taken)
			if hex then
				wc2_artifacts.place_item(hex.x, hex.y, artifact_id)
			else
				wc2_artifacts.give_item(leader, artifact_id, true)
			end
		end
	end
end

-- Spawn reinforcements on turn 1
on_event("turn 1", function(cx)
	if not upgrades.pending_reinforcements then return end
	local sorted_sides = {}
	for side_num in pairs(upgrades.pending_reinforcements) do table.insert(sorted_sides, side_num) end
	table.sort(sorted_sides)
	for _, side_num in ipairs(sorted_sides) do
		local count = upgrades.pending_reinforcements[side_num]
		local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
		if leader then
			local adj_hexes = { wesnoth.map.get_adjacent_hexes(leader.x, leader.y) }
			local recruit_list = wesnoth.sides[side_num].recruit
			local spawned = 0
			for _, hex in ipairs(adj_hexes) do
				if spawned >= count then break end
				if not wesnoth.units.get(hex.x, hex.y) then
					wesnoth.wml_actions.unit {
						side = side_num,
						type = recruit_list[mathx.random(#recruit_list)],
						x = hex.x, y = hex.y,
						moves = 0, generate_name = true,
					}
					local u = wesnoth.units.get(hex.x, hex.y)
					if u then wc2_training.apply(u) end
					spawned = spawned + 1
				end
			end
		end
	end
	upgrades.pending_reinforcements = nil
	for side_num = 1, (wml.variables.wc2_player_count or 1) do
		wesnoth.sides[side_num].variables["wc2x_pending_reinf"] = 0
	end
end)

-- Training ground XP
on_event("side turn end", function(cx)
	local side_num = wesnoth.current.side
	if not wc2_scenario.is_human_side(side_num) then return end
	local forts = fortifications[side_num]
	if not forts then return end
	local config = upgrades.config
	for _, loc in ipairs(forts.training) do
		local u = wesnoth.units.get(loc.x, loc.y)
		if u and u.side == side_num and not u.canrecruit then
			u.experience = u.experience + config.training_ground_xp_per_turn
			u:advance(true, true)
			wesnoth.interface.float_label(loc.x, loc.y, string.format("+%d XP", config.training_ground_xp_per_turn))
		end
	end
end)

-- Barracks spawn
on_event("side turn", function(cx)
	local side_num = wesnoth.current.side
	if not wc2_scenario.is_human_side(side_num) then return end
	local config = upgrades.config
	if wesnoth.current.turn % config.barracks_spawn_interval ~= 0 then return end
	local forts = fortifications[side_num]
	if not forts then return end
	local recruit_list = wesnoth.sides[side_num].recruit
	if #recruit_list == 0 then return end
	for _, loc in ipairs(forts.barracks) do
		if not wesnoth.units.get(loc.x, loc.y) then
			wesnoth.wml_actions.unit {
				side = side_num,
				type = recruit_list[mathx.random(#recruit_list)],
				x = loc.x, y = loc.y,
				moves = 0, generate_name = true,
			}
			local u = wesnoth.units.get(loc.x, loc.y)
			if u then wc2_training.apply(u) end
			wesnoth.interface.float_label(loc.x, loc.y, "Barracks recruit!")
		end
	end
end)

return upgrades
