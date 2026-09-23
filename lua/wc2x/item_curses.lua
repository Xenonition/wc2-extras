-- Recurring item curses that plain [effect] data cannot express

local _ = wesnoth.textdomain 'wesnoth-wc'

local item_curses = {}

local BLOODPRICE_HP_LOSS = 8

function item_curses.init()
	-- "side turn" fires before start-of-turn healing, so like poison the loss lands after the enemy's turn
	wesnoth.game_events.add_repeating("side turn", function()
		local bearers = wesnoth.units.find_on_map {
			side = wesnoth.current.side,
			wml.tag.has_attack { special_id = "wc2x_bloodprice" },
		}
		for i, u in ipairs(bearers) do
			local loss = math.min(BLOODPRICE_HP_LOSS, u.hitpoints - 1)
			if loss > 0 then
				u.hitpoints = u.hitpoints - loss
				wesnoth.interface.float_label(u.x, u.y, "<span color='#cc2222'>" .. tostring(_ "bloodprice") .. " -" .. loss .. "</span>")
			end
		end
	end)
end

return item_curses
