-- WC3 Debug Panel — hidden context menu activated via Wocopedia easter egg

local _ = wesnoth.textdomain 'wesnoth-wc'

local debug_panel = {}

wc2x_debug_enabled = false

function debug_panel.init(config)
	debug_panel.config = config

	wc2_utils.menu_item {
		id = "9_WC3_Debug_Panel",
		description = "WC3 Debug",
		image = "icons/action/editor-tool-unit_25.png",
		synced = false,
		filter = function()
			return wc2x_debug_enabled == true
		end,
		handler = function(cx)
			debug_panel.show(cx.x1, cx.y1)
		end,
	}
end

local function msg(text)
	wesnoth.wml_actions.chat { speaker = "WC3", message = text }
end

local function pick_option(title, message, options)
	local choice = gui.show_narration({
		title = title,
		message = message,
	}, options)
	return choice
end

function debug_panel.show(x, y)
	local side_num = wesnoth.interface.get_viewing_side()
	local unit = wesnoth.units.get(x, y)

	local entries = {}
	local function add(label, action)
		table.insert(entries, { label = label, action = action })
	end

	add("AI: Show Tactics", function()
		if wc2x.ai_director and wc2x.ai_director.debug then
			wc2x.ai_director.debug.tactics()
		end
	end)

	add("AI: Show Weights", function()
		local player_count = wml.variables.wc2_player_count or 1
		local side_options = {}
		local side_map = {}
		for i = player_count + 1, #wesnoth.sides do
			if wesnoth.sides[i].controller == "ai" then
				table.insert(side_options, "Side " .. i)
				table.insert(side_map, i)
			end
		end
		if #side_options == 0 then msg("No AI sides found"); return end
		local pick = pick_option("Pick Side", "Show AI weights for which side?", side_options)
		if pick >= 1 and pick <= #side_map then
			wc2x.ai_director.debug.weights(side_map[pick])
		end
	end)

	add("AI: Toggle Labels", function()
		if wc2x.ai_director and wc2x.ai_director.debug then
			wc2x.ai_director.debug.labels()
		end
	end)

	add("Upgrades: View All", function()
		for s = 1, (wml.variables.wc2_player_count or 1) do
			local lines = {}
			local upgrade_ids = { "castle_hex", "supply_village", "base_income", "vision_radius", "reinforcements", "barracks", "training_ground" }
			for _, uid in ipairs(upgrade_ids) do
				local count = wc2x.upgrades.get_count(s, uid)
				if count > 0 then
					table.insert(lines, string.format("%s x%d", uid, count))
				end
			end
			msg(string.format("Side %d: %s", s, #lines > 0 and table.concat(lines, ", ") or "(none)"))
		end
	end)

	add("Upgrades: Grant", function()
		local upgrade_options = {
			"castle_hex", "supply_village", "base_income",
			"vision_radius", "reinforcements", "barracks", "training_ground",
		}
		local pick = pick_option("Grant Upgrade", "Grant which upgrade to side " .. side_num .. "?", upgrade_options)
		if pick >= 1 and pick <= #upgrade_options then
			wc2x.upgrades.purchase(side_num, upgrade_options[pick])
			msg(string.format("Granted %s to side %d", upgrade_options[pick], side_num))
		end
	end)

	if unit then
		add("Unit: +50 XP", function()
			unit.experience = unit.experience + 50
			msg(string.format("%s +50 XP (%d/%d)", unit.name, unit.experience, unit.max_experience))
			wesnoth.wml_actions.advance_unit { x = unit.x, y = unit.y, animate = false }
		end)

		add("Unit: Full Heal", function()
			unit.hitpoints = unit.max_hitpoints
			unit.moves = unit.max_moves
			unit.status.poisoned = false
			unit.status.slowed = false
			msg(string.format("%s fully healed", unit.name))
		end)

		add("Unit: Max Level", function()
			while unit.experience < unit.max_experience do
				unit.experience = unit.max_experience
				wesnoth.wml_actions.advance_unit { x = unit.x, y = unit.y, animate = false }
				unit = wesnoth.units.get(x, y)
				if not unit then break end
			end
			if unit then
				msg(string.format("%s advanced to %s", unit.name, unit.type))
			end
		end)
	end

	add("Gold: +100", function()
		wesnoth.sides[side_num].gold = wesnoth.sides[side_num].gold + 100
		msg("+100 gold to side " .. side_num)
	end)

	add("Gold: +500", function()
		wesnoth.sides[side_num].gold = wesnoth.sides[side_num].gold + 500
		msg("+500 gold to side " .. side_num)
	end)

	add("Disable Debug Menu", function()
		wc2x_debug_enabled = false
		msg("Debug menu disabled.")
	end)

	local option_strings = {}
	for _, e in ipairs(entries) do
		table.insert(option_strings, e.label)
	end

	local header = unit
		and string.format("%s [%s] (%d,%d) — Side %d — %d gold",
			unit.name, unit.type, x, y, side_num, wesnoth.sides[side_num].gold)
		or string.format("(%d,%d) — Side %d — %d gold",
			x, y, side_num, wesnoth.sides[side_num].gold)

	local choice = pick_option("WC3 Debug", header, option_strings)

	if choice >= 1 and choice <= #entries then
		entries[choice].action()
	end
end

return debug_panel
