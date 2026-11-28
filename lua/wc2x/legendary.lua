-- Legendary leaders: from config.legendary_from_scenario, every enemy leader gets the legendary
-- trait (HP, damage, moves, laurel overlay) and affixes from config.legendary_affixes (built from
-- shrine buffs), each its own trait. No drop. State: unit variable wc2x_legendary, and the WML array
-- wc2x_legends (id, name, desc, slain) for the objectives note.

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

-- the affix is one trait named after it (shown beside "legendary"), holding the effects of its
-- usable parts; a part that is a trait of its own (Ability: Steadfast...) gives up its effects
local function apply_affix(u, affix)
	local title = string.lower(affix.title)
	local trait = {
		id = "wc2x_affix_" .. title, male_name = title, female_name = title,
		description = string.upper(affix.desc:sub(1, 1)) .. affix.desc:sub(2) .. ".",
	}
	for i, buff in ipairs(usable_parts(u, affix)) do
		if buff.trait then
			for j, child in ipairs(buff.trait) do
				if child[1] == "effect" then table.insert(trait, child) end
			end
		else
			table.insert(trait, wml.tag.effect(buff.effect))
		end
	end
	u:add_modification("trait", trait)
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
					apply_affix(u, affix)
					table.insert(picked, affix)
					break
				end
			end
		end
	end
	return picked
end

-- base bonus every legendary leader gets on top of its affixes, in place of WC2's heroic trait.
-- Moves must be an effect: WC2 creates enemy leaders with max_moves = 0, but LotI's
-- update_stats (LotI_Era lua/stats.lua) recreates every unit from its type and modifications,
-- so a directly set max_moves is lost and leaders end up with their type's moves
function legendary.trait()
	local config = wc2x.config
	return {
		id = "wc2x_legendary", male_name = _ "legendary", female_name = _ "female^legendary",
		description = string.format(tostring(_ "+%s hitpoints, +%s damage on all attacks, +%d moves."),
			config.legendary_hp_bonus, config.legendary_damage_bonus, config.legendary_moves),
		wml.tag.effect { apply_to = "hitpoints", increase_total = config.legendary_hp_bonus },
		wml.tag.effect { apply_to = "attack", increase_damage = config.legendary_damage_bonus },
		wml.tag.effect { apply_to = "movement", increase = config.legendary_moves },
		wml.tag.effect { apply_to = "overlay", add = "misc/laurel.png" },
	}
end

-- Dawnbreakers (dawnbreakers.lua) roll from the same affix table
legendary.roll_affixes = roll_affixes

function legendary.make(u, count)
	u:remove_modifications({ id = "heroic" }, "trait")
	u:add_modification("trait", legendary.trait())
	local picked = roll_affixes(u, count)
	-- no title of our own: LotI already titles every AI leader on "unit placed"
	local descs = {}
	for i, affix in ipairs(picked) do
		table.insert(descs, string.format("%s (%s)", affix.title, affix.desc))
	end
	u.hitpoints = u.max_hitpoints
	u.variables.wc2x_legendary = true
	-- the side keeps its own rolled leader aggression (enemy_scaling); until 0.19.0 a legend was
	-- forced to at least 1.0 and kept walking out of its keep to die
	return { id = u.id, name = u.name, desc = table.concat(descs, "; ") }
end

-- every enemy leader on the map (not the neutral, Dawnbreaker or boss sides, which have none at
-- start), in side order
local function make_all()
	local scenario_num = wc2_scenario.scenario_num()
	local config = wc2x.config
	if scenario_num < config.legendary_from_scenario then return end
	local count = config.legendary_affix_count[scenario_num] or 0
	local leaders = wesnoth.units.find_on_map { canrecruit = true }
	table.sort(leaders, function(a, b) return a.side < b.side end)
	local legends, lines = {}, {}
	for _i, u in ipairs(leaders) do
		local vars = wesnoth.sides[u.side].variables
		if not wc2_scenario.is_human_side(u.side) and not vars["wc2x_is_neutral"]
			and not vars["wc2x_is_dawnbreaker"] then
			local legend = legendary.make(u, count)
			table.insert(legends, legend)
			table.insert(lines, string.format("%s: %s", tostring(legend.name), legend.desc))
		end
	end
	if #legends == 0 then return end
	wml.array_access.set("wc2x_legends", legends)
	wesnoth.wml_actions.message {
		speaker = "narrator",
		caption = _ "Legends Rise",
		image = "misc/laurel.png",
		message = tostring(_ "Every enemy leader here is a legend:") .. "\n" .. table.concat(lines, "\n"),
	}
end

-- objectives note, or nil when this map has no legendary leaders
function legendary.status_text()
	local lines = {}
	for _i, legend in ipairs(wml.array_access.get("wc2x_legends")) do
		if legend.slain then
			table.insert(lines, string.format(tostring(_ "Legendary leader %s: slain."), tostring(legend.name)))
		else
			table.insert(lines, string.format(tostring(_ "Legendary leader %s (%s)."),
				tostring(legend.name), legend.desc))
		end
	end
	-- a map started before 0.19.0 has one legend, stored as a single record
	local old = wml.variables.wc2x_legendary
	if old and old.name then
		table.insert(lines, old.slain and string.format(tostring(_ "Legendary leader %s: slain."), tostring(old.name))
			or string.format(tostring(_ "Legendary leader %s (%s)."), tostring(old.name), old.desc))
	end
	if #lines == 0 then return nil end
	return table.concat(lines, "\n")
end

function legendary.init()
	-- the variable outlives the map; clear it before this map's leaders are made
	on_event("prestart", function()
		wml.variables.wc2x_legendary = nil
		wml.variables.wc2x_legends = nil
	end)

	-- after prestart, where [wc2_enemy] creates the leaders
	on_event("start", function()
		make_all()
		wesnoth.wml_actions.wc2_objectives {}
	end)

	on_event("die", function()
		local ec = wesnoth.current.event_context
		if not ec.x1 then return end -- [fire_event] without a unit (LotI zombies)
		local u = wesnoth.units.get(ec.x1, ec.y1)
		if not (u and u.variables.wc2x_legendary) then return end
		for i, legend in ipairs(wml.array_access.get("wc2x_legends")) do
			if legend.id == u.id then wml.variables[("wc2x_legends[%d].slain"):format(i - 1)] = true end
		end
		if wml.variables.wc2x_legendary then wml.variables["wc2x_legendary.slain"] = true end
		wesnoth.interface.float_label(ec.x1, ec.y1, _ "Legend slain!", "255,215,0")
		wesnoth.wml_actions.wc2_objectives {}
	end)
end

return legendary
