local on_event = wesnoth.game_events.add_repeating
local _ = wesnoth.textdomain 'wesnoth-wc'
local wc2_utils = wesnoth.require("./../game_mechanics/utils.lua")
local unit_finder = {}

local function collect_tags(side_num)
	local by_id = {}
	local units = wesnoth.units.find_on_map { side = side_num }
	for _, u in ipairs(units) do
		local mods = wml.get_child(u.__cfg, "modifications")
		if mods then
			for trait in wml.child_range(mods, "trait") do
				local id = trait.id
				if id and id ~= "" then
					if not by_id[id] then
						by_id[id] = {
							name = tostring(trait.male_name or trait.female_name or trait.name or id),
							count = 0, kind = "trait",
						}
					end
					by_id[id].count = by_id[id].count + 1
				end
			end
		end
		local abilities = wml.get_child(u.__cfg, "abilities")
		if abilities then
			for _, child in ipairs(abilities) do
				local ability = child[2]
				local id = ability.id
				if id and id ~= "" then
					if not by_id[id] then
						by_id[id] = {
							name = tostring(ability.name or id),
							count = 0, kind = "ability",
						}
					end
					by_id[id].count = by_id[id].count + 1
				end
			end
		end
	end
	local list = {}
	for id, info in pairs(by_id) do
		info.id = id
		table.insert(list, info)
	end
	table.sort(list, function(a, b)
		if a.kind ~= b.kind then return a.kind < b.kind end
		return a.name < b.name
	end)
	return list
end

local function find_units_with_tag(side_num, tag_id, tag_kind)
	local results = {}
	local units = wesnoth.units.find_on_map { side = side_num }
	for _, u in ipairs(units) do
		local found = false
		if tag_kind == "trait" then
			local mods = wml.get_child(u.__cfg, "modifications")
			if mods then
				for trait in wml.child_range(mods, "trait") do
					if trait.id == tag_id then found = true; break end
				end
			end
		elseif tag_kind == "ability" then
			local abilities = wml.get_child(u.__cfg, "abilities")
			if abilities then
				for _, child in ipairs(abilities) do
					if child[2].id == tag_id then found = true; break end
				end
			end
		end
		if found then
			table.insert(results, {
				name = tostring(u.name),
				type_name = tostring(u.__cfg.language_name),
				level = u.level,
				x = u.x, y = u.y,
			})
		end
	end
	table.sort(results, function(a, b)
		if a.level ~= b.level then return a.level > b.level end
		return a.name < b.name
	end)
	return results
end

function unit_finder.show()
	local side_num = wesnoth.interface.get_viewing_side()
	local tags = collect_tags(side_num)
	if #tags == 0 then
		gui.show_narration({ title = _ "Unit Finder", message = _ "No traits or abilities found on your units." })
		return
	end

	local options = {}
	for _, tag in ipairs(tags) do
		local kind_label = tag.kind == "trait" and _ "Trait" or _ "Ability"
		table.insert(options, tostring(tag.name) .. " [" .. tostring(kind_label) .. "] (" .. tag.count .. ")")
	end
	table.insert(options, tostring(_ "Cancel"))

	local choice = gui.show_narration(
		{ title = _ "Unit Finder", message = _ "Select a trait or ability:" },
		options
	)
	if choice == #options then return end

	local tag = tags[choice]
	local units = find_units_with_tag(side_num, tag.id, tag.kind)
	if #units == 0 then return end

	while true do
		local unit_options = {}
		for _, u in ipairs(units) do
			table.insert(unit_options, u.name .. " — " .. u.type_name .. " (Lv" .. u.level .. ")")
		end
		table.insert(unit_options, tostring(_ "Back"))
		table.insert(unit_options, tostring(_ "Close"))

		local pick = gui.show_narration(
			{ title = tostring(tag.name), message = #units .. " units found:" },
			unit_options
		)

		if pick == #unit_options then
			return
		elseif pick == #unit_options - 1 then
			return unit_finder.show()
		else
			local target = units[pick]
			if target then
				wesnoth.wml_actions.scroll_to { x = target.x, y = target.y }
			end
		end
	end
end

function unit_finder.init()
	wc2_utils.menu_item {
		id = "3_WC3_Unit_Finder",
		description = _ "Find Unit by Trait/Ability",
		image = "icons/action/editor-tool-unit_25.png",
		synced = false,
		filter = function(x, y)
			local u = wesnoth.units.get(x, y)
			if u and u.side == wesnoth.current.side then
				return true
			end
			return not u
		end,
		handler = function()
			unit_finder.show()
		end,
	}
end

return unit_finder
