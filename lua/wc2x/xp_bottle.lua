-- XP bottle: finishing a map early leaves a bottle next to each player's leader on the next map,
-- worth more the more turns are left, flattening toward a per-scenario ceiling (see config).
-- Only the owner's units can drink it. It pays
-- in XP, the currency players farm for, so finishing beats farming. placement.deliver_pending
-- places it.

local _ = wesnoth.textdomain 'wesnoth-wc'
local on_event = wesnoth.game_events.add_repeating

local bottle = {}

bottle.IMAGE = "items/wc3-xp-bottle.png"

local function last_player_side()
	return wml.variables.wc2_highest_player_side or wml.variables.wc2_player_count or 1
end

-- for the scenario being won; integer division keeps it identical on every client
function bottle.amount()
	local config = wc2x.config
	local turns_left = math.max(wesnoth.scenario.turns - wesnoth.current.turn, 0)
	local ceilings = config.xp_bottle_ceiling
	local ceiling = ceilings[math.min(wc2_scenario.scenario_num(), #ceilings)]
	return ceiling * turns_left // (turns_left + config.xp_bottle_half_turns)
end

function bottle.place(hex, side_num, amount)
	wesnoth.wml_actions.item {
		x = hex.x, y = hex.y,
		image = bottle.IMAGE,
		z_order = 20,
		wml.tag.variables { wc2x_xp_bottle = amount, wc2x_owner = side_num },
	}
	wesnoth.wml_actions.label {
		x = hex.x, y = hex.y,
		text = string.format("+%d XP", amount),
		color = "127,255,127",
	}
end

function bottle.init()
	-- stored for every player still in the game; scenario 5's victory ends the campaign, so its
	-- leftover variable is never read. Priority 10: runs before scenario.lua's victory handler
	-- (priority 0) moves wc2_scenario on to the next map, so amount() sees the map just won.
	on_event("victory", function()
		local amount = bottle.amount()
		if amount <= 0 then return end
		for side_num = 1, last_player_side() do
			if wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1] then
				wesnoth.sides[side_num].variables["wc2x_pending_xp_bottle"] = amount
			end
		end
	end, 10)

	-- fired by dropping.lua when a unit stops on an [item]
	on_event("wc2_drop_pickup", function()
		local item = wc2_dropping.current_item
		local amount = item and item.variables.wc2x_xp_bottle
		if not amount then return end
		local ec = wesnoth.current.event_context
		local unit = wesnoth.units.get(ec.x1, ec.y1)
		if not unit or unit.side ~= item.variables.wc2x_owner then return end

		wc2_dropping.item_taken = true
		wesnoth.allow_undo(false)
		wesnoth.wml_actions.label { x = ec.x1, y = ec.y1, text = "" }
		wesnoth.interface.float_label(ec.x1, ec.y1, string.format("+%d XP", amount), "127,255,127")
		wesnoth.interface.add_chat_message("WC3", string.format(tostring(
			_ "%s drinks the XP bottle: +%d XP."), tostring(unit.name), amount))
		unit.experience = unit.experience + amount
		-- the engine asks the unit's owner which advancement to take (synced), as after a fight
		unit:advance(true, true)
	end)
end

return bottle
