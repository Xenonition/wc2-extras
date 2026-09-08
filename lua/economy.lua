-- WC2 Extras — enemy economy rework
-- Replaces WC2's lump-sum enemy gold with income-based economy.
-- Hooks into wc2_enemy action to modify gold after WC2's own setup.

local on_event = wesnoth.game_events.add_repeating
local config = wc2x.config

local economy = {}

-- Calculate how much starting gold enemies should get
function economy.get_enemy_starting_gold(side_num)
	local player_gold = 0
	local player_count = wml.variables.wc2_player_count or 1
	for i = 1, player_count do
		player_gold = player_gold + wesnoth.sides[i].gold
	end
	local avg_player_gold = player_gold / player_count

	local enemy_power = wml.variables["wc2_difficulty.enemy_power"] or 6
	local difficulty_scale = config.difficulty_gold_scale[enemy_power] or 1.0

	return math.ceil(avg_player_gold * config.enemy_gold_multiplier * difficulty_scale)
end

-- After WC2 sets up enemies, override their gold to our income-based amount
-- We hook "prestart" at a late priority so WC2's wc2_enemy has already run
on_event("start", function(cx)
	local player_count = wml.variables.wc2_player_count or 1
	local target_gold = economy.get_enemy_starting_gold(1)

	for side_num = player_count + 1, #wesnoth.sides do
		local side = wesnoth.sides[side_num]
		if side.controller == "ai" then
			side.gold = target_gold
			-- Give enemies a baseline income so they don't stall completely
			-- even if they lose all villages
			side.base_income = config.enemy_min_gold_per_turn
		end
	end
end)

return economy
