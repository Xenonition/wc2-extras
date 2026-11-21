-- War chest: winning a map early pays each player config.war_chest_income_pct of their
-- theoretical income for every turn left. Theoretical income = the side's own income
-- (side.total_income: base income + its villages, before upkeep) plus an even share of every
-- village the players don't hold yet, as if they had gone on to take the whole map. So grabbing
-- the last villages before finishing earns nothing extra. Paid before the gacha and shop; it is
-- ordinary gold afterwards and counts toward carryover like any other.

local _ = wesnoth.textdomain 'wesnoth-wc'
local on_event = wesnoth.game_events.add_repeating

local war_chest = {}

local function player_sides()
	local last_side = wml.variables.wc2_highest_player_side or wml.variables.wc2_player_count or 1
	local res = {}
	for side_num = 1, last_side do
		table.insert(res, wesnoth.sides[side_num])
	end
	return res
end

local function has_leader(side_num)
	return wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1] ~= nil
end

-- villages each player with a leader would gain if the players took every one they don't hold
-- (enemy-owned or neutral); whole-number maths so every client pays the same
function war_chest.village_share()
	local held, paid_sides = 0, 0
	for _i, side in ipairs(player_sides()) do
		held = held + side.num_villages
		if has_leader(side.side) then paid_sides = paid_sides + 1 end
	end
	if paid_sides == 0 then return 0 end
	local unheld = math.max(#wesnoth.map.find { gives_income = true } - held, 0)
	return unheld // paid_sides
end

function war_chest.theoretical_income(side_num, share)
	local side = wesnoth.sides[side_num]
	return side.total_income + share * side.village_gold
end

function war_chest.amount(side_num, share)
	local turns_left = math.max(wesnoth.scenario.turns - wesnoth.current.turn, 0)
	return war_chest.theoretical_income(side_num, share) * turns_left
		* wc2x.config.war_chest_income_pct // 100
end

function war_chest.init()
	-- Priority 10: before scenario.lua's victory handler (default priority 0.5) opens the gacha and
	-- shop. Scenario 5's victory ends the campaign.
	on_event("victory", function()
		if wml.variables.wc2_scenario >= 5 then return end
		local turns_left = math.max(wesnoth.scenario.turns - wesnoth.current.turn, 0)
		local share = war_chest.village_share()
		for _i, side in ipairs(player_sides()) do
			local amount = has_leader(side.side) and war_chest.amount(side.side, share) or 0
			if amount > 0 then
				side.gold = side.gold + amount
				wesnoth.interface.add_chat_message("WC3", string.format(tostring(
					_ "War chest for side %d: %d turns left × %d income (counting %d villages not yet held) × %d%% = %d gold."),
					side.side, turns_left, war_chest.theoretical_income(side.side, share), share,
					wc2x.config.war_chest_income_pct, amount))
			end
		end
	end, 10)
end

return war_chest
