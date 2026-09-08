-- WC2 Extras — persistent upgrades
-- State stored in side variables (wc2x_upgrades.*), persists via savegame.

local on_event = wesnoth.game_events.add_repeating

local upgrades = {}

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
	local config = upgrades.config

	local gold_count = upgrades.get_count(side_num, "starting_gold")
	if gold_count > 0 then
		side.gold = side.gold + (gold_count * 15)
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

	local recall_count = upgrades.get_count(side_num, "recall_discount")
	if recall_count > 0 then
		side.recall_cost = math.max(side.recall_cost - (recall_count * 3), 1)
	end

	local reinf_count = upgrades.get_count(side_num, "reinforcements")
	if reinf_count > 0 then
		upgrades.pending_reinforcements = upgrades.pending_reinforcements or {}
		upgrades.pending_reinforcements[side_num] = reinf_count
	end
end

function upgrades.apply_castle_hexes(side_num)
	local config = upgrades.config
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
	end

	for i = 1, barracks_count do
		if placed >= #expansion_candidates then break end
		placed = placed + 1
		local loc = expansion_candidates[placed]
		wesnoth.current.map[loc] = "Ch"
		local side = wesnoth.sides[side_num]
		local key = string.format("wc2x_barracks.%d", i)
		side.variables[key .. ".x"] = loc.x
		side.variables[key .. ".y"] = loc.y
		wesnoth.wml_actions.item {
			x = loc.x, y = loc.y,
			image = "scenery/castle-ruins.png",
			z_order = -5,
		}
	end

	for i = 1, training_count do
		if placed >= #expansion_candidates then break end
		placed = placed + 1
		local loc = expansion_candidates[placed]
		wesnoth.current.map[loc] = "Ch"
		local side = wesnoth.sides[side_num]
		local key = string.format("wc2x_training_ground.%d", i)
		side.variables[key .. ".x"] = loc.x
		side.variables[key .. ".y"] = loc.y
		wesnoth.wml_actions.item {
			x = loc.x, y = loc.y,
			image = "scenery/tent-fancy-red.png",
			z_order = -5,
		}
	end

	for i = 1, castle_count do
		if placed >= #expansion_candidates then break end
		placed = placed + 1
		wesnoth.current.map[expansion_candidates[placed]] = "Ch"
	end
end

-- Apply at scenario start
on_event("wc2_start", function(cx)
	upgrades.pending_reinforcements = {}
	for side_num = 1, (wml.variables.wc2_player_count or 1) do
		upgrades.apply_castle_hexes(side_num)
		upgrades.apply_for_side(side_num)
	end
end)

-- Spawn reinforcements on turn 1
on_event("turn 1", function(cx)
	if not upgrades.pending_reinforcements then return end
	for side_num, count in pairs(upgrades.pending_reinforcements) do
		local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
		if leader then
			local adj_hexes = { wesnoth.map.get_adjacent_hexes(leader) }
			local recruit_list = stringx.split(wesnoth.sides[side_num].recruit)
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
					spawned = spawned + 1
				end
			end
		end
	end
	upgrades.pending_reinforcements = nil
end)

-- Training ground XP
on_event("side turn end", function(cx)
	local side_num = wesnoth.current.side
	if not wc2_scenario.is_human_side(side_num) then return end
	local side = wesnoth.sides[side_num]
	local config = upgrades.config
	local training_count = upgrades.get_count(side_num, "training_ground")
	for i = 1, training_count do
		local key = string.format("wc2x_training_ground.%d", i)
		local tx = side.variables[key .. ".x"]
		local ty = side.variables[key .. ".y"]
		if tx and ty then
			local u = wesnoth.units.get(tx, ty)
			if u and u.side == side_num and not u.canrecruit then
				u.experience = u.experience + config.training_ground_xp_per_turn
				u:advance(true, true)
				wesnoth.interface.float_label(tx, ty, string.format("+%d XP", config.training_ground_xp_per_turn))
			end
		end
	end
end)

-- Barracks spawn
on_event("side turn", function(cx)
	local side_num = wesnoth.current.side
	if not wc2_scenario.is_human_side(side_num) then return end
	local config = upgrades.config
	if wesnoth.current.turn % config.barracks_spawn_interval ~= 0 then return end
	local side = wesnoth.sides[side_num]
	local barracks_count = upgrades.get_count(side_num, "barracks")
	local recruit_list = stringx.split(side.recruit)
	if #recruit_list == 0 then return end
	for i = 1, barracks_count do
		local key = string.format("wc2x_barracks.%d", i)
		local bx = side.variables[key .. ".x"]
		local by = side.variables[key .. ".y"]
		if bx and by and not wesnoth.units.get(bx, by) then
			wesnoth.wml_actions.unit {
				side = side_num,
				type = recruit_list[mathx.random(#recruit_list)],
				x = bx, y = by,
				moves = 0, generate_name = true,
			}
			wesnoth.interface.float_label(bx, by, "Barracks recruit!")
		end
	end
end)

-- Unit discount refund
on_event("recruit", function(cx)
	local side_num = wesnoth.current.side
	if not wc2_scenario.is_human_side(side_num) then return end
	local u = wesnoth.units.get(cx.x1, cx.y1)
	if not u then return end
	local discount = wesnoth.sides[side_num].variables["wc2x_unit_discount." .. u.type] or 0
	if discount > 0 then
		wesnoth.sides[side_num].gold = wesnoth.sides[side_num].gold + discount
	end
end)

return upgrades
