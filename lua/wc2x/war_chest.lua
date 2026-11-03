-- War chest: winning a map early pays each player config.war_chest_income_pct of their income
-- (side.total_income: base income + villages, before upkeep) for every turn left. Stalling a won
-- map earns about one income per turn; this makes finishing worth most of that in gold, on top of
-- the shop discount, XP bottle and carryover. Paid before the gacha and shop so it can be spent
-- at the discounted prices.

local _ = wesnoth.textdomain 'wesnoth-wc'
local on_event = wesnoth.game_events.add_repeating

local war_chest = {}

local PAID_VAR = "wc2x_war_chest_paid"

-- whole-number maths so every client pays the same
function war_chest.amount(side_num)
	local turns_left = math.max(wesnoth.scenario.turns - wesnoth.current.turn, 0)
	return wesnoth.sides[side_num].total_income * turns_left * wc2x.config.war_chest_income_pct // 100
end

-- gold paid at the last victory; wc2_store_carryover leaves it out so it isn't counted twice
function war_chest.paid(side_num)
	return wesnoth.sides[side_num].variables[PAID_VAR] or 0
end

function war_chest.init()
	-- Priority 10: before scenario.lua's victory handler (priority 0) opens the shop and moves
	-- wc2_scenario on, and before the carryover event. Scenario 5's victory ends the campaign.
	on_event("victory", function()
		if wml.variables.wc2_scenario >= 5 then return end
		local turns_left = math.max(wesnoth.scenario.turns - wesnoth.current.turn, 0)
		local last_side = wml.variables.wc2_highest_player_side or wml.variables.wc2_player_count or 1
		for side_num = 1, last_side do
			local side = wesnoth.sides[side_num]
			local amount = 0
			if wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1] then
				amount = war_chest.amount(side_num)
			end
			side.variables[PAID_VAR] = amount
			if amount > 0 then
				side.gold = side.gold + amount
				wesnoth.interface.add_chat_message("WC3", string.format(tostring(
					_ "War chest for side %d: %d turns left × %d income × %d%% = %d gold."),
					side_num, turns_left, side.total_income, wc2x.config.war_chest_income_pct, amount))
			end
		end
	end, 10)
end

return war_chest
