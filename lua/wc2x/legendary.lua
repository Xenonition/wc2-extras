-- Legendary leaders: from config.legendary_from_scenario, one random enemy leader per map gets
-- the legendary trait (HP, damage, laurel overlay) and affixes from config.legendary_affixes (built from shrine
-- buffs). Killing it drops a WC2 artifact. State: unit variable wc2x_legendary, and the WML
-- variable wc2x_legendary (name, desc, slain) for the objectives note.

local _ = wesnoth.textdomain 'wesnoth-wc'
local on_event = wesnoth.game_events.add_repeating

local legendary = {}

local function resolve(part)
	if type(part) ~= "string" then return part end
	for i, buff in ipairs(wc2x.config.shrine_buffs) do
		if buff.name == part then return buff end
	end
	error("legendary affix: no shrine buff named " .. part)
end

local function usable_parts(u, affix)
	local parts = {}
	for i, part in ipairs(affix.parts) do
		local buff = resolve(part)
		if not wc2x.poi.buff_is_redundant(u, buff) then table.insert(parts, buff) end
	end
	return parts
end

local function apply_affix(u, affix, affix_index)
	-- re-checked per part: an earlier part can make a later one redundant
	for j, part in ipairs(affix.parts) do
		local buff = resolve(part)
		if not wc2x.poi.buff_is_redundant(u, buff) then
			if buff.trait then
				u:add_modification("trait", buff.trait)
			else
				u:add_modification("object", {
					id = string.format("wc2x_legendary_%d_%d", affix_index, j),
					wml.tag.effect(buff.effect),
				})
			end
		end
	end
end

-- weighted pick without replacement; affixes with no usable part are skipped
local function roll_affixes(u, count)
	local affixes = wc2x.config.legendary_affixes
	local picked, exclude = {}, {}
	for n = 1, count do
		local total = 0
		for i, affix in ipairs(affixes) do
			if not exclude[i] and #usable_parts(u, affix) == 0 then exclude[i] = true end
			if not exclude[i] then total = total + affix.weight end
		end
		if total <= 0 then break end
		local roll, cum = mathx.random(total), 0
		for i, affix in ipairs(affixes) do
			if not exclude[i] then
				cum = cum + affix.weight
				if roll <= cum then
					exclude[i] = true
					apply_affix(u, affix, i)
					table.insert(picked, affix)
					break
				end
			end
		end
	end
	return picked
end

-- base bonus every legendary leader gets on top of its affixes, in place of WC2's heroic trait.
-- Moves are set in legendary.make, not here: enemy leaders are created with 0 moves to hold
-- their keep, and a movement effect would add to the unit type's moves after any rebuild
function legendary.trait()
	local config = wc2x.config
	return {
		id = "wc2x_legendary", male_name = _ "legendary", female_name = _ "female^legendary",
		description = string.format(tostring(_ "+%s hitpoints, +%s damage on all attacks, +%d moves."),
			config.legendary_hp_bonus, config.legendary_damage_bonus, config.legendary_moves),
		wml.tag.effect { apply_to = "hitpoints", increase_total = config.legendary_hp_bonus },
		wml.tag.effect { apply_to = "attack", increase_damage = config.legendary_damage_bonus },
		wml.tag.effect { apply_to = "overlay", add = "misc/laurel.png" },
	}
end

function legendary.make(u, count)
	-- removing a trait rebuilds the unit from its type, which also undoes the leader's 0 moves
	u:remove_modifications({ id = "heroic" }, "trait")
	u:add_modification("trait", legendary.trait())
	local picked = roll_affixes(u, count)
	-- no title of our own: LotI already titles every AI leader on "unit placed"
	local descs = {}
	for i, affix in ipairs(picked) do
		table.insert(descs, string.format("%s (%s)", affix.title, affix.desc))
	end
	u.max_moves = wc2x.config.legendary_moves
	u.hitpoints = u.max_hitpoints
	u.variables.wc2x_legendary = true

	-- a legend fights: raise the side's rolled leader aggression (enemy_scaling) to at least the
	-- legendary floor. Stored in the side variable too, which ai_director restores after castle_defense
	local side = wesnoth.sides[u.side]
	local la = math.max(tonumber(side.variables["wc2x_ai_leader_aggression"] or "0"),
		wc2x.config.legendary_leader_aggression)
	side.variables["wc2x_ai_leader_aggression"] = string.format("%.1f", la)
	wesnoth.wml_actions.modify_side { side = u.side, wml.tag.ai { leader_aggression = la } }
	wml.variables.wc2x_legendary = {
		name = u.name,
		desc = table.concat(descs, "; "),
	}
end

local function pick_leader()
	local scenario_num = wc2_scenario.scenario_num()
	local config = wc2x.config
	if scenario_num < config.legendary_from_scenario then return end
	local count = config.legendary_affix_count[scenario_num] or 0
	local candidates = {}
	for i, u in ipairs(wesnoth.units.find_on_map { canrecruit = true }) do
		local side = wesnoth.sides[u.side]
		if not wc2_scenario.is_human_side(u.side) and not side.variables["wc2x_is_neutral"] then
			table.insert(candidates, u)
		end
	end
	if #candidates == 0 then return end
	local u = candidates[mathx.random(#candidates)]
	legendary.make(u, count)
	wesnoth.wml_actions.message {
		speaker = "narrator",
		caption = _ "A Legend Rises",
		image = wesnoth.unit_types[u.type].image,
		message = string.format(tostring(
			_ "%s leads the enemy here: %s. Slay them and an artifact is yours."),
			tostring(u.name), wml.variables["wc2x_legendary.desc"]),
	}
end

-- objectives note, or nil when this map has no legendary leader
function legendary.status_text()
	local legend = wml.variables.wc2x_legendary
	if not legend then return nil end
	if legend.slain then
		return string.format(tostring(_ "Legendary leader %s: slain."), tostring(legend.name))
	end
	return string.format(tostring(_ "Legendary leader %s (%s). Drops an artifact when slain."),
		tostring(legend.name), legend.desc)
end

function legendary.init()
	-- the variable outlives the map; clear it before this map's leaders are made
	on_event("prestart", function()
		wml.variables.wc2x_legendary = nil
	end)

	-- after prestart, where [wc2_enemy] creates the leaders
	on_event("start", function()
		pick_leader()
		wesnoth.wml_actions.wc2_objectives {}
	end)

	on_event("die", function()
		local ec = wesnoth.current.event_context
		local u = wesnoth.units.get(ec.x1, ec.y1)
		if not (u and u.variables.wc2x_legendary) then return end
		local artifacts = wc2_artifacts.get_artifact_list()
		-- owner defaults to the killer's side (see artifacts.place_item), so carryover returns it
		wc2_artifacts.place_item(ec.x1, ec.y1, mathx.random(#artifacts))
		wml.variables["wc2x_legendary.slain"] = true
		wesnoth.interface.float_label(ec.x1, ec.y1, _ "Legend slain!", "255,215,0")
		wesnoth.wml_actions.wc2_objectives {}
	end)
end

return legendary
