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
	return gui.show_narration({ title = title, message = message }, options)
end

local function show_info(title, text)
	gui.show_narration({ title = title, message = text })
end

---------------------------------------------------------------------------
-- AI submenu
---------------------------------------------------------------------------
local function show_ai_menu(side_num)
	local player_count = wml.variables.wc2_player_count or 1
	local ai_sides = {}
	for i = player_count + 1, #wesnoth.sides do
		if wesnoth.sides[i].controller == "ai" then
			table.insert(ai_sides, i)
		end
	end
	if #ai_sides == 0 then msg("No AI sides found"); return end

	local options = {
		"View All Tactics",
		"View Weights (pick side)",
		"View Personality (pick side)",
		"Force Tactic",
		"Toggle Map Labels",
		"Toggle Unit Overlays",
		"Back",
	}
	local choice = pick_option("AI Director", "Side count: " .. #ai_sides, options)

	if choice == 1 then
		local text = wc2x.ai_director.debug.get_tactics_text()
		show_info("AI Tactics", text)

	elseif choice == 2 then
		local side_opts = {}
		for _, s in ipairs(ai_sides) do table.insert(side_opts, "Side " .. s) end
		local pick = pick_option("Pick Side", "Show weights for:", side_opts)
		if pick >= 1 and pick <= #ai_sides then
			local text = wc2x.ai_director.debug.get_weights_text(ai_sides[pick])
			show_info("AI Weights — Side " .. ai_sides[pick], text)
		end

	elseif choice == 3 then
		local side_opts = {}
		for _, s in ipairs(ai_sides) do table.insert(side_opts, "Side " .. s) end
		local pick = pick_option("Pick Side", "Show personality for:", side_opts)
		if pick >= 1 and pick <= #ai_sides then
			local text = wc2x.ai_director.debug.get_personality_text(ai_sides[pick])
			show_info("AI Personality — Side " .. ai_sides[pick], text)
		end

	elseif choice == 4 then
		local side_opts = {}
		for _, s in ipairs(ai_sides) do table.insert(side_opts, "Side " .. s) end
		local pick = pick_option("Force Tactic", "Which side?", side_opts)
		if pick >= 1 and pick <= #ai_sides then
			local target = ai_sides[pick]
			local slot_opts = { "strategic", "opportunistic" }
			local slot_pick = pick_option("Force Tactic", "Which slot?", slot_opts)
			if slot_pick >= 1 and slot_pick <= 2 then
				local slot = slot_opts[slot_pick]
				local names = wc2x.ai_director.debug.get_tactic_names()
				local tactic_list = names[slot]
				if #tactic_list == 0 then msg("No tactics for slot " .. slot); return end
				local t_pick = pick_option("Force Tactic", "Side " .. target .. " " .. slot .. ":", tactic_list)
				if t_pick >= 1 and t_pick <= #tactic_list then
					wc2x.ai_director.debug.force(target, slot, tactic_list[t_pick])
					msg(string.format("Forced side %d %s → %s", target, slot, tactic_list[t_pick]))
				end
			end
		end

	elseif choice == 5 then
		wc2x.ai_director.debug.labels()

	elseif choice == 6 then
		wc2x.ai_director.debug.tactics()
	end
end

---------------------------------------------------------------------------
-- Upgrades submenu
---------------------------------------------------------------------------
local UPGRADE_IDS = { "castle_hex", "supply_village", "base_income", "vision_radius", "reinforcements", "barracks", "training_ground" }

local function show_upgrades_menu(side_num)
	local options = { "View All Sides", "Grant Upgrade", "Back" }
	local choice = pick_option("Upgrades", "Your side: " .. side_num, options)

	if choice == 1 then
		local lines = {}
		for s = 1, (wml.variables.wc2_player_count or 1) do
			table.insert(lines, string.format("<b>Side %d:</b>", s))
			local any = false
			for _, uid in ipairs(UPGRADE_IDS) do
				local count = wc2x.upgrades.get_count(s, uid)
				if count > 0 then
					table.insert(lines, string.format("  %s x%d", uid, count))
					any = true
				end
			end
			if not any then table.insert(lines, "  (none)") end
		end
		show_info("Upgrades", table.concat(lines, "\n"))

	elseif choice == 2 then
		local pick = pick_option("Grant Upgrade", "Grant to side " .. side_num .. ":", UPGRADE_IDS)
		if pick >= 1 and pick <= #UPGRADE_IDS then
			wc2x.upgrades.purchase(side_num, UPGRADE_IDS[pick])
			msg(string.format("Granted %s to side %d", UPGRADE_IDS[pick], side_num))
		end
	end
end

---------------------------------------------------------------------------
-- Unit submenu — nested by category
---------------------------------------------------------------------------
local function show_unit_menu(unit, x, y)
	local categories = { "Progression", "Stats", "Combat", "Traits", "Misc", "Back" }
	local header = string.format("%s [%s] — HP %d/%d — XP %d/%d",
		unit.name, unit.type, unit.hitpoints, unit.max_hitpoints,
		unit.experience, unit.max_experience)

	local cat = pick_option("Unit: " .. tostring(unit.name), header, categories)

	if cat == 1 then -- Progression
		local opts = { "+50 XP", "+100 XP", "Max Level", "Back" }
		local pick = pick_option("Progression", header, opts)
		if pick == 1 or pick == 2 then
			local amount = pick == 1 and 50 or 100
			unit.experience = unit.experience + amount
			msg(string.format("%s +%d XP (%d/%d)", unit.name, amount, unit.experience, unit.max_experience))
			if unit.experience >= unit.max_experience then
				wesnoth.wml_actions.advance_unit {
					wml.tag.filter { x = x, y = y },
					animate = false,
				}
				unit = wesnoth.units.get(x, y)
				if unit then msg(string.format("  → advanced to %s", unit.type)) end
			end
		elseif pick == 3 then
			local safety = 0
			while unit and unit.experience < unit.max_experience and safety < 20 do
				unit.experience = unit.max_experience
				wesnoth.wml_actions.advance_unit {
					wml.tag.filter { x = x, y = y },
					animate = false,
				}
				unit = wesnoth.units.get(x, y)
				safety = safety + 1
			end
			if unit then msg(string.format("%s → %s (max level)", unit.name, unit.type)) end
		end

	elseif cat == 2 then -- Stats
		local opts = { "+10 Max HP", "+20 Max HP", "+2 Movement", "+4 Movement", "Full Heal", "Back" }
		local pick = pick_option("Stats", header, opts)
		if pick == 1 or pick == 2 then
			local amount = pick == 1 and 10 or 20
			unit:add_modification("object", {
				id = "wc3_dbg_hp_" .. tostring(mathx.random(9999)),
				wml.tag.effect { apply_to = "hitpoints", increase_total = amount },
			})
			unit.hitpoints = math.min(unit.hitpoints + amount, unit.max_hitpoints)
			msg(string.format("%s: +%d HP (%d/%d)", unit.name, amount, unit.hitpoints, unit.max_hitpoints))
		elseif pick == 3 or pick == 4 then
			local amount = pick == 3 and 2 or 4
			unit:add_modification("object", {
				id = "wc3_dbg_mv_" .. tostring(mathx.random(9999)),
				wml.tag.effect { apply_to = "movement", increase = amount },
			})
			msg(string.format("%s: +%d movement (%d)", unit.name, amount, unit.max_moves))
		elseif pick == 5 then
			unit.hitpoints = unit.max_hitpoints
			unit.moves = unit.max_moves
			unit.status.poisoned = false
			unit.status.slowed = false
			msg(string.format("%s fully healed", unit.name))
		end

	elseif cat == 3 then -- Combat
		local opts = {
			"+10% Damage (all)", "+25% Damage (all)",
			"+1 Strike (all)", "+2 Strikes (all)",
			"Add Alt Damage Type",
			"Back",
		}
		local pick = pick_option("Combat", header, opts)
		if pick == 1 or pick == 2 then
			local pct = pick == 1 and "10%" or "25%"
			unit:add_modification("object", {
				id = "wc3_dbg_dmg_" .. tostring(mathx.random(9999)),
				wml.tag.effect { apply_to = "attack", increase_damage = pct },
			})
			msg(string.format("%s: +%s damage", unit.name, pct))
		elseif pick == 3 or pick == 4 then
			local amount = pick == 3 and 1 or 2
			unit:add_modification("object", {
				id = "wc3_dbg_strikes_" .. tostring(mathx.random(9999)),
				wml.tag.effect { apply_to = "attack", increase_attacks = amount },
			})
			msg(string.format("%s: +%d strikes", unit.name, amount))
		elseif pick == 5 then
			local types = { "blade", "pierce", "impact", "fire", "cold", "arcane" }
			local tp = pick_option("Damage Type", "Add alternative type:", types)
			if tp >= 1 and tp <= #types then
				unit:add_modification("object", {
					id = "wc3_dbg_dt_" .. types[tp],
					wml.tag.effect {
						apply_to = "attack",
						wml.tag.set_specials {
							mode = "append",
							wml.tag.damage_type {
								id = "wc3_dbg_alt_" .. types[tp],
								alternative_type = types[tp],
							},
						},
					},
				})
				msg(string.format("%s: +%s alternative type", unit.name, types[tp]))
			end
		end

	elseif cat == 4 then -- Traits
		local opts = { "Strong", "Resilient", "Quick", "Intelligent", "Dextrous", "Healthy", "Back" }
		local pick = pick_option("Traits", header, opts)
		local trait_defs = {
			{ id = "strong", name = "strong",
				wml.tag.effect { apply_to = "attack", increase_damage = 1 },
				wml.tag.effect { apply_to = "hitpoints", increase_total = 2 } },
			{ id = "resilient", name = "resilient",
				wml.tag.effect { apply_to = "hitpoints", increase_total = "7" } },
			{ id = "quick", name = "quick",
				wml.tag.effect { apply_to = "movement", increase = 1 },
				wml.tag.effect { apply_to = "hitpoints", increase_total = "-5%" } },
			{ id = "intelligent", name = "intelligent",
				wml.tag.effect { apply_to = "max_experience", increase = "-20%" } },
			{ id = "dextrous", name = "dextrous",
				wml.tag.effect { apply_to = "attack", increase_damage = 1,
					wml.tag.filter_attack { range = "ranged" } } },
			{ id = "healthy", name = "healthy",
				wml.tag.effect { apply_to = "hitpoints", increase_total = 2 },
				wml.tag.effect { apply_to = "hitpoints", times = "per level", increase_total = 1 } },
		}
		if pick >= 1 and pick <= #trait_defs then
			unit:add_modification("trait", trait_defs[pick])
			msg(string.format("%s: added %s trait", unit.name, trait_defs[pick].name))
		end

	elseif cat == 5 then -- Misc
		local opts = { "Set Upkeep: Free", "Set Upkeep: Full", "Add Hero Overlay", "Back" }
		local pick = pick_option("Misc", header, opts)
		if pick == 1 then
			unit.upkeep = "free"
			msg(string.format("%s: upkeep → free", unit.name))
		elseif pick == 2 then
			unit.upkeep = "full"
			msg(string.format("%s: upkeep → full", unit.name))
		elseif pick == 3 then
			unit:add_modification("object", {
				id = "wc3_dbg_hero_overlay",
				wml.tag.effect { apply_to = "overlay", add = "misc/hero-icon.png" },
			})
			msg(string.format("%s: hero overlay added", unit.name))
		end
	end
end

---------------------------------------------------------------------------
-- Main menu
---------------------------------------------------------------------------
function debug_panel.show(x, y)
	local side_num = wesnoth.interface.get_viewing_side()
	local unit = wesnoth.units.get(x, y)

	local options = { "AI Director", "Upgrades" }
	if unit then table.insert(options, "Unit: " .. tostring(unit.name)) end
	table.insert(options, "Gold: +100")
	table.insert(options, "Gold: +500")
	table.insert(options, "Disable Debug Menu")

	local header = string.format("Side %d — %d gold", side_num, wesnoth.sides[side_num].gold)
	if unit then
		header = string.format("%s [%s] (%d,%d)\n%s", unit.name, unit.type, x, y, header)
	end

	local choice = pick_option("WC3 Debug", header, options)

	if choice == 1 then
		show_ai_menu(side_num)
	elseif choice == 2 then
		show_upgrades_menu(side_num)
	elseif unit and choice == 3 then
		show_unit_menu(unit, x, y)
	else
		local offset = unit and 3 or 2
		if choice == offset + 1 then
			wesnoth.sides[side_num].gold = wesnoth.sides[side_num].gold + 100
			msg("+100 gold to side " .. side_num)
		elseif choice == offset + 2 then
			wesnoth.sides[side_num].gold = wesnoth.sides[side_num].gold + 500
			msg("+500 gold to side " .. side_num)
		elseif choice == offset + 3 then
			wc2x_debug_enabled = false
			msg("Debug menu disabled.")
		end
	end
end

return debug_panel
