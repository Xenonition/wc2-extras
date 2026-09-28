-- Right-click "Retrain": re-roll a fresh recruit's training for a share of its recruit cost.
-- Only units recruited this turn qualify, so it replaces the recruit-and-dismiss loop without
-- letting veterans be re-rolled later.

local _ = wesnoth.textdomain 'wesnoth-wc'

local retrain = {}

local TRAIT_ID = "wc2x_trained"

function retrain.cost(u)
	local ut = wesnoth.unit_types[u.type]
	return math.ceil((ut and ut.cost or 0) * retrain.config.retrain_cost_pct / 100)
end

function retrain.eligible(u)
	return u ~= nil
		and u.side == wesnoth.current.side
		and wc2_scenario.is_human_side(u.side)
		and u.variables.wc2x_recruit_turn == wesnoth.current.turn
		and wesnoth.sides[u.side].gold >= retrain.cost(u)
end

function retrain.init(config)
	retrain.config = config

	wesnoth.game_events.add_repeating("recruit", function()
		local ctx = wesnoth.current.event_context
		local u = wesnoth.units.get(ctx.x1, ctx.y1)
		if u then u.variables.wc2x_recruit_turn = wesnoth.current.turn end
	end)

	wc2_utils.menu_item {
		id = "2_WC3_Retrain",
		description = string.format(tostring(_ "Retrain (re-roll training for %d%% of the unit's cost)"), config.retrain_cost_pct),
		image = "icons/action/editor-tool-unit_25.png",
		synced = true,
		filter = function(x, y)
			return retrain.eligible(wesnoth.units.get(x, y))
		end,
		handler = function(cx)
			local u = wesnoth.units.get(cx.x1, cx.y1)
			-- re-checked here because the handler also runs on every other client
			if not retrain.eligible(u) then return end
			local cost = retrain.cost(u)
			wesnoth.sides[u.side].gold = wesnoth.sides[u.side].gold - cost
			u:remove_modifications({ id = TRAIT_ID }, "trait")
			wc2_training.apply(u)
			wesnoth.interface.float_label(u.x, u.y, string.format(tostring(_ "retrained (-%d gold)"), cost), "255,215,0")
		end,
	}
end

return retrain
