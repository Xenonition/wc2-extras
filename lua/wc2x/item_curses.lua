-- Recurring item curses that plain [effect] data cannot express

local _ = wesnoth.textdomain 'wesnoth-wc'

local item_curses = {}

local BLOODPRICE_HP_LOSS = 4
local LONE_MENDER_HEAL = 16

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

	-- Mender's Ankh: "turn refresh" fires after start-of-turn healing, so the pick only considers
	-- allies still wounded after it and the heal is never spent on someone a healer topped up
	wesnoth.game_events.add_repeating("turn refresh", function()
		local menders = wesnoth.units.find_on_map {
			side = wesnoth.current.side,
			ability = "wc2x_lone_mender",
		}
		for _i, m in ipairs(menders) do
			local wounded = {}
			for _j, u in ipairs(wesnoth.units.find_on_map { wml.tag.filter_adjacent { id = m.id } }) do
				if not wesnoth.sides.is_enemy(u.side, m.side) and u.hitpoints < u.max_hitpoints then
					table.insert(wounded, u)
				end
			end
			if #wounded > 0 then
				local u = wounded[mathx.random(#wounded)]
				local heal = math.min(LONE_MENDER_HEAL, u.max_hitpoints - u.hitpoints)
				u.hitpoints = u.hitpoints + heal
				wesnoth.interface.float_label(u.x, u.y, "<span color='#44dd44'>+" .. heal .. "</span>")
			end
		end
	end)
end

return item_curses
