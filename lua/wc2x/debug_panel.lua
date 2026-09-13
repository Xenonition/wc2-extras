-- WC3 Debug Panel — hidden context menu activated via Wocopedia easter egg
-- All state-changing actions go through evaluate_single for MP sync safety.
-- Dialog flow runs on the acting client only; mutations run on both clients.

local _ = wesnoth.textdomain 'wesnoth-wc'

local debug_panel = {}

wc2x_debug_enabled = false

local dbg_counter = 0
local loti_free_craft_sides = {}
local loti_orig_get_counts = nil
local loti_orig_add = nil

---------------------------------------------------------------------------
-- Shared definitions — both clients reference these by index
---------------------------------------------------------------------------
local UPGRADE_IDS = { "castle_hex", "supply_village", "base_income", "vision_radius", "reinforcements", "barracks", "training_ground" }

local TRAIT_DEFS = {
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
local TRAIT_NAMES = { "Strong", "Resilient", "Quick", "Intelligent", "Dextrous", "Healthy" }

local ABILITY_DEFS = {
	{ id = "wc3_dbg_regen", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.regenerate { id = "regenerates", name = "regenerates",
			description = "Heals 8 HP per turn at the start of every turn",
			value = 8, poison = "cured" } } } },
	{ id = "wc3_dbg_skirmisher", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.skirmisher { id = "skirmisher", name = "skirmisher",
			description = "This unit can move through enemy ZOC without penalty" } } } },
	{ id = "wc3_dbg_ambush", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.hides { id = "ambush", name = "ambush",
			description = "Invisible in forest terrain",
			wml.tag.filter_self { wml.tag.filter_location { terrain = "*^F*" } } } } } },
	{ id = "wc3_dbg_submerge", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.hides { id = "submerge", name = "submerge",
			description = "Invisible in shallow and deep water",
			wml.tag.filter_self { wml.tag.filter_location { terrain = "W*,S*" } } } } } },
	{ id = "wc3_dbg_nightstalk", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.hides { id = "nightstalk", name = "nightstalk",
			description = "Invisible at night",
			wml.tag.filter_self { wml.tag.filter_location {
				time_of_day = "chaotic" } } } } } },
	{ id = "wc3_dbg_teleport", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.teleport { id = "teleport", name = "teleport",
			description = "Teleport between owned villages",
			wml.tag.tunnel { id = "wc3_dbg_tp",
				wml.tag.source { terrain = "*^V*" },
				wml.tag.target { terrain = "*^V*" },
				wml.tag.filter { ability = "teleport" },
			} } } } },
	{ id = "wc3_dbg_steadfast", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.resistance {
			id = "steadfast", name = "steadfast",
			description = "Double resistance when defending (max 50%)",
			multiply = 2, max_value = 50, active_on = "defense",
			apply_to = "blade,pierce,impact,fire,cold,arcane",
			wml.tag.filter_base_value { greater_than = 0, less_than = 50 } } } } },
	{ id = "wc3_dbg_leadership", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.leadership { id = "leadership", name = "leadership",
			description = "+25% damage to adjacent lower-level allies",
			value = 25 } } } },
	{ id = "wc3_dbg_heals4", wml.tag.effect { apply_to = "new_ability",
		wml.tag.abilities { wml.tag.heals { id = "healing", name = "heals +4",
			description = "Heals adjacent allies 4 HP per turn",
			value = 4, affect_allies = true, affect_self = false } } } },
	{ id = "wc3_dbg_drain", wml.tag.effect { apply_to = "attack",
		wml.tag.set_specials { mode = "append",
			wml.tag.drains { id = "drain", name = "drain",
				description = "Absorbs 50% of damage dealt", value = 50 } } } },
	{ id = "wc3_dbg_poison", wml.tag.effect { apply_to = "attack",
		wml.tag.set_specials { mode = "append",
			wml.tag.poison { id = "poison", name = "poison",
				description = "Attacks poison the target" } } } },
	{ id = "wc3_dbg_backstab", wml.tag.effect { apply_to = "attack",
		wml.tag.filter_attack { range = "melee" },
		wml.tag.set_specials { mode = "append",
			wml.tag.backstab { id = "backstab", name = "backstab",
				description = "Double damage when enemy is flanked", multiply = 2 } } } },
	{ id = "wc3_dbg_marksman", wml.tag.effect { apply_to = "attack",
		wml.tag.filter_attack { range = "ranged" },
		wml.tag.set_specials { mode = "append",
			wml.tag.chance_to_hit { id = "marksman", name = "marksman",
				description = "Always 60% chance to hit on offense",
				value = 60, active_on = "offense", cumulative = true } } } },
	{ id = "wc3_dbg_charge", wml.tag.effect { apply_to = "attack",
		wml.tag.filter_attack { range = "melee" },
		wml.tag.set_specials { mode = "append",
			wml.tag.damage { id = "charge", name = "charge",
				description = "Double damage on offense (both attacker and defender)",
				multiply = 2, active_on = "offense", apply_to = "both" } } } },
	{ id = "wc3_dbg_berserk", wml.tag.effect { apply_to = "attack",
		wml.tag.filter_attack { range = "melee" },
		wml.tag.set_specials { mode = "append",
			wml.tag.berserk { id = "berserk", name = "berserk",
				description = "Fight to the death in melee",
				value = 30 } } } },
	{ id = "wc3_dbg_firststrike", wml.tag.effect { apply_to = "attack",
		wml.tag.filter_attack { range = "melee" },
		wml.tag.set_specials { mode = "append",
			wml.tag.firststrike { id = "firststrike", name = "first strike",
				description = "Always strikes first in melee" } } } },
}
local ABILITY_NAMES = {
	"Regenerates", "Skirmisher", "Ambush", "Submerge", "Nightstalk",
	"Teleport", "Steadfast", "Leadership", "Heals +4",
	"Drain", "Poison", "Backstab", "Marksman", "Charge", "Berserk", "First Strike",
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function msg(text, acting_side)
	if acting_side and wesnoth.interface.get_viewing_side() ~= acting_side then return end
	wesnoth.wml_actions.chat { speaker = "WC3", message = text }
end

local function pick_option(title, message, options)
	return gui.show_narration({ title = title, message = message }, options)
end

local function show_info(title, text)
	gui.show_narration({ title = title, message = text })
end

local NO_ACTION = { action = "" }

---------------------------------------------------------------------------
-- Apply action — runs on BOTH clients after sync
---------------------------------------------------------------------------
local function apply_action(data)
	if not data or data.action == "" then return end
	local s = data.acting_side

	if data.action == "gold" then
		wesnoth.sides[data.side].gold = wesnoth.sides[data.side].gold + data.amount
		msg(string.format("+%d gold to side %d", data.amount, data.side), s)

	elseif data.action == "unit_xp" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		unit.experience = unit.experience + data.amount
		msg(string.format("%s +%d XP (%d/%d)", unit.name, data.amount, unit.experience, unit.max_experience), s)
		if unit.experience >= unit.max_experience then
			unit:advance(true, false)
			unit = wesnoth.units.get(data.x, data.y)
			if unit then msg(string.format("  → advanced to %s", unit.type), s) end
		end

	elseif data.action == "unit_maxlevel" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		local safety = 0
		while unit and #unit.advances_to > 0 and safety < 20 do
			unit.experience = unit.max_experience
			unit:advance(true, false)
			unit = wesnoth.units.get(data.x, data.y)
			safety = safety + 1
		end
		if unit then msg(string.format("%s → %s (max level)", unit.name, unit.type), s) end

	elseif data.action == "unit_hp" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		dbg_counter = dbg_counter + 1
		unit:add_modification("object", {
			id = "wc3_dbg_hp_" .. dbg_counter,
			wml.tag.effect { apply_to = "hitpoints", increase_total = data.amount },
		})
		unit.hitpoints = math.min(unit.hitpoints + data.amount, unit.max_hitpoints)
		msg(string.format("%s: +%d HP (%d/%d)", unit.name, data.amount, unit.hitpoints, unit.max_hitpoints), s)

	elseif data.action == "unit_mv" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		dbg_counter = dbg_counter + 1
		unit:add_modification("object", {
			id = "wc3_dbg_mv_" .. dbg_counter,
			wml.tag.effect { apply_to = "movement", increase = data.amount },
		})
		msg(string.format("%s: +%d movement (%d)", unit.name, data.amount, unit.max_moves), s)

	elseif data.action == "unit_heal" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		unit.hitpoints = unit.max_hitpoints
		unit.moves = unit.max_moves
		unit.status.poisoned = false
		unit.status.slowed = false
		msg(string.format("%s fully healed", unit.name), s)

	elseif data.action == "unit_dmg" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		dbg_counter = dbg_counter + 1
		unit:add_modification("object", {
			id = "wc3_dbg_dmg_" .. dbg_counter,
			wml.tag.effect { apply_to = "attack", increase_damage = data.pct },
		})
		msg(string.format("%s: +%s damage", unit.name, data.pct), s)

	elseif data.action == "unit_strikes" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		dbg_counter = dbg_counter + 1
		unit:add_modification("object", {
			id = "wc3_dbg_strikes_" .. dbg_counter,
			wml.tag.effect { apply_to = "attack", increase_attacks = data.amount },
		})
		msg(string.format("%s: +%d strikes", unit.name, data.amount), s)

	elseif data.action == "unit_altdmg" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		unit:add_modification("object", {
			id = "wc3_dbg_dt_" .. data.dtype,
			wml.tag.effect {
				apply_to = "attack",
				wml.tag.set_specials {
					mode = "append",
					wml.tag.damage_type {
						id = "wc3_dbg_alt_" .. data.dtype,
						alternative_type = data.dtype,
					},
				},
			},
		})
		msg(string.format("%s: +%s alternative type", unit.name, data.dtype), s)

	elseif data.action == "unit_trait" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		local def = TRAIT_DEFS[data.idx]
		if not def then return end
		unit:add_modification("trait", def)
		msg(string.format("%s: added %s trait", unit.name, def.name), s)

	elseif data.action == "unit_ability" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		local def = ABILITY_DEFS[data.idx]
		if not def then return end
		unit:add_modification("object", def)
		msg(string.format("%s: added %s", unit.name, ABILITY_NAMES[data.idx] or "ability"), s)

	elseif data.action == "unit_upkeep" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		unit.upkeep = data.value
		msg(string.format("%s: upkeep → %s", unit.name, data.value), s)

	elseif data.action == "unit_overlay" then
		local unit = wesnoth.units.get(data.x, data.y)
		if not unit then return end
		unit:add_modification("object", {
			id = "wc3_dbg_hero_overlay",
			wml.tag.effect { apply_to = "overlay", add = "misc/hero-icon.png" },
		})
		msg(string.format("%s: hero overlay added", unit.name), s)

	elseif data.action == "upgrade" then
		wc2x.upgrades.purchase(data.side, data.upgrade_id)
		msg(string.format("Granted %s to side %d", data.upgrade_id, data.side), s)

	elseif data.action == "force_tactic" then
		wc2x.ai_director.debug.force(data.side, data.slot, data.tactic)
		msg(string.format("Forced side %d %s → %s", data.side, data.slot, data.tactic), s)

	elseif data.action == "loti_free_craft" then
		if not loti or not loti.gem then
			msg("LotI Era not loaded — toggle has no effect", s)
			return
		end
		if not loti_orig_get_counts then
			loti_orig_get_counts = loti.gem.get_counts
			loti_orig_add = loti.gem.add
			loti.gem.get_counts = function()
				if loti_free_craft_sides[wesnoth.current.side] then
					local counts = {}
					for _ = 1, #loti.gem.types do table.insert(counts, 999) end
					return counts
				end
				return loti_orig_get_counts()
			end
			loti.gem.add = function(gem, count)
				if loti_free_craft_sides[wesnoth.current.side] then return end
				loti_orig_add(gem, count)
			end
		end
		loti_free_craft_sides[s] = not loti_free_craft_sides[s] or nil
		if loti_free_craft_sides[s] then
			msg("LotI free crafting ON for side " .. s, s)
		else
			msg("LotI free crafting OFF for side " .. s, s)
		end
	end
end

---------------------------------------------------------------------------
-- Dialog collection — runs on acting client only (inside evaluate_single)
-- Returns a flat action table; NO_ACTION for read-only / cancelled.
---------------------------------------------------------------------------
local function collect_ai_action(side_num)
	local player_count = wml.variables.wc2_player_count or 1
	local ai_sides = {}
	for i = player_count + 1, #wesnoth.sides do
		if wesnoth.sides[i].controller == "ai" then
			table.insert(ai_sides, i)
		end
	end
	if #ai_sides == 0 then return NO_ACTION end

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
		show_info("AI Tactics", wc2x.ai_director.debug.get_tactics_text())
	elseif choice == 2 then
		local side_opts = {}
		for _, s in ipairs(ai_sides) do table.insert(side_opts, "Side " .. s) end
		local pick = pick_option("Pick Side", "Show weights for:", side_opts)
		if pick >= 1 and pick <= #ai_sides then
			show_info("AI Weights — Side " .. ai_sides[pick],
				wc2x.ai_director.debug.get_weights_text(ai_sides[pick]))
		end
	elseif choice == 3 then
		local side_opts = {}
		for _, s in ipairs(ai_sides) do table.insert(side_opts, "Side " .. s) end
		local pick = pick_option("Pick Side", "Show personality for:", side_opts)
		if pick >= 1 and pick <= #ai_sides then
			show_info("AI Personality — Side " .. ai_sides[pick],
				wc2x.ai_director.debug.get_personality_text(ai_sides[pick]))
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
				if #tactic_list == 0 then return NO_ACTION end
				local t_pick = pick_option("Force Tactic", "Side " .. target .. " " .. slot .. ":", tactic_list)
				if t_pick >= 1 and t_pick <= #tactic_list then
					return { action = "force_tactic", side = target, slot = slot, tactic = tactic_list[t_pick] }
				end
			end
		end
	elseif choice == 5 then
		wc2x.ai_director.debug.labels()
	elseif choice == 6 then
		wc2x.ai_director.debug.tactics()
	end
	return NO_ACTION
end

local function collect_upgrades_action(side_num)
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
			return { action = "upgrade", side = side_num, upgrade_id = UPGRADE_IDS[pick] }
		end
	end
	return NO_ACTION
end

local function collect_unit_action(unit, x, y)
	local categories = { "Progression", "Stats", "Combat", "Traits", "Abilities", "Misc", "Back" }
	local header = string.format("%s [%s] — HP %d/%d — XP %d/%d",
		unit.name, unit.type, unit.hitpoints, unit.max_hitpoints,
		unit.experience, unit.max_experience)

	local cat = pick_option("Unit: " .. tostring(unit.name), header, categories)

	if cat == 1 then -- Progression
		local opts = { "+50 XP", "+100 XP", "Max Level", "Back" }
		local pick = pick_option("Progression", header, opts)
		if pick == 1 then return { action = "unit_xp", x = x, y = y, amount = 50 }
		elseif pick == 2 then return { action = "unit_xp", x = x, y = y, amount = 100 }
		elseif pick == 3 then return { action = "unit_maxlevel", x = x, y = y }
		end

	elseif cat == 2 then -- Stats
		local opts = { "+10 Max HP", "+20 Max HP", "+2 Movement", "+4 Movement", "Full Heal", "Back" }
		local pick = pick_option("Stats", header, opts)
		if pick == 1 then return { action = "unit_hp", x = x, y = y, amount = 10 }
		elseif pick == 2 then return { action = "unit_hp", x = x, y = y, amount = 20 }
		elseif pick == 3 then return { action = "unit_mv", x = x, y = y, amount = 2 }
		elseif pick == 4 then return { action = "unit_mv", x = x, y = y, amount = 4 }
		elseif pick == 5 then return { action = "unit_heal", x = x, y = y }
		end

	elseif cat == 3 then -- Combat
		local opts = {
			"+10% Damage (all)", "+25% Damage (all)",
			"+1 Strike (all)", "+2 Strikes (all)",
			"Add Alt Damage Type",
			"Back",
		}
		local pick = pick_option("Combat", header, opts)
		if pick == 1 then return { action = "unit_dmg", x = x, y = y, pct = "10%" }
		elseif pick == 2 then return { action = "unit_dmg", x = x, y = y, pct = "25%" }
		elseif pick == 3 then return { action = "unit_strikes", x = x, y = y, amount = 1 }
		elseif pick == 4 then return { action = "unit_strikes", x = x, y = y, amount = 2 }
		elseif pick == 5 then
			local types = { "blade", "pierce", "impact", "fire", "cold", "arcane" }
			local tp = pick_option("Damage Type", "Add alternative type:", types)
			if tp >= 1 and tp <= #types then
				return { action = "unit_altdmg", x = x, y = y, dtype = types[tp] }
			end
		end

	elseif cat == 4 then -- Traits
		local opts = {}
		for _, n in ipairs(TRAIT_NAMES) do table.insert(opts, n) end
		table.insert(opts, "Back")
		local pick = pick_option("Traits", header, opts)
		if pick >= 1 and pick <= #TRAIT_DEFS then
			return { action = "unit_trait", x = x, y = y, idx = pick }
		end

	elseif cat == 5 then -- Abilities
		local opts = {
			"Regenerates (+8 HP/turn)",
			"Skirmisher (ignore ZOC)",
			"Ambush (invisible in forest)",
			"Submerge (invisible in water)",
			"Nightstalk (invisible at night)",
			"Teleport (between villages)",
			"Steadfast (2x resist on defense)",
			"Leadership (+25% to adjacent)",
			"Heals +4 (heals adjacent allies)",
			"Drain (absorb 50% damage dealt)",
			"Poison (attacks poison target)",
			"Backstab (double flanking damage)",
			"Marksman (60% ranged on offense)",
			"Charge (double melee on offense)",
			"Berserk (fight until death)",
			"First Strike (melee always first)",
			"Back",
		}
		local pick = pick_option("Abilities", header, opts)
		if pick >= 1 and pick <= #ABILITY_DEFS then
			return { action = "unit_ability", x = x, y = y, idx = pick }
		end

	elseif cat == 6 then -- Misc
		local opts = { "Set Upkeep: Free", "Set Upkeep: Full", "Add Hero Overlay", "Back" }
		local pick = pick_option("Misc", header, opts)
		if pick == 1 then return { action = "unit_upkeep", x = x, y = y, value = "free" }
		elseif pick == 2 then return { action = "unit_upkeep", x = x, y = y, value = "full" }
		elseif pick == 3 then return { action = "unit_overlay", x = x, y = y }
		end
	end
	return NO_ACTION
end

---------------------------------------------------------------------------
-- Main entry — collects action from dialog, returns flat table
---------------------------------------------------------------------------
local function collect_action(x, y)
	local side_num = wesnoth.current.side
	local unit = wesnoth.units.get(x, y)

	local options = { "AI Director", "Upgrades" }
	if unit then table.insert(options, "Unit: " .. tostring(unit.name)) end
	table.insert(options, "Gold: +100")
	table.insert(options, "Gold: +500")
	if loti and loti.gem then
		local label = loti_free_craft_sides[side_num] and "LotI Free Craft: ON (click to disable)" or "LotI Free Craft: OFF (click to enable)"
		table.insert(options, label)
	end
	table.insert(options, "Disable Debug Menu")

	local header = string.format("Side %d — %d gold", side_num, wesnoth.sides[side_num].gold)
	if unit then
		header = string.format("%s [%s] (%d,%d)\n%s", unit.name, unit.type, x, y, header)
	end

	local choice = pick_option("WC3 Debug", header, options)

	if choice == 1 then
		return collect_ai_action(side_num)
	elseif choice == 2 then
		return collect_upgrades_action(side_num)
	elseif unit and choice == 3 then
		return collect_unit_action(unit, x, y)
	else
		local offset = unit and 3 or 2
		if choice == offset + 1 then
			return { action = "gold", side = side_num, amount = 100 }
		elseif choice == offset + 2 then
			return { action = "gold", side = side_num, amount = 500 }
		else
			local loti_offset = offset + 2
			local has_loti = loti and loti.gem
			if has_loti and choice == loti_offset + 1 then
				return { action = "loti_free_craft" }
			end
			local disable_idx = has_loti and (loti_offset + 2) or (loti_offset + 1)
			if choice == disable_idx then
				wc2x_debug_enabled = false
				msg("Debug menu disabled.")
				return NO_ACTION
			end
		end
	end
	return NO_ACTION
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
function debug_panel.show(x, y)
	local acting_side = wesnoth.current.side
	local res = wesnoth.sync.evaluate_single(_ "Debug Panel", function()
		local data = collect_action(x, y)
		if data.action ~= "" then
			data.acting_side = acting_side
		end
		return data
	end, acting_side)
	apply_action(res)
end

function debug_panel.init(config)
	debug_panel.config = config

	wc2_utils.menu_item {
		id = "9_WC3_Debug_Panel",
		description = "WC3 Debug",
		image = "icons/action/editor-tool-unit_25.png",
		synced = true,
		filter = function()
			return wc2x_debug_enabled == true
		end,
		handler = function(cx)
			debug_panel.show(cx.x1, cx.y1)
		end,
	}
end

return debug_panel
