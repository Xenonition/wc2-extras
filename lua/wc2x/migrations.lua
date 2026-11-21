-- One-off repairs for units saved with broken buff definitions. Runs on preload, which every
-- client executes on identical saved state, so the edits stay in sync. Each repair only matches
-- units that still carry the broken data, so it is a no-op once they are fixed.

local migrations = {}

local function find_buff(trait_id)
	for i, buff in ipairs(wc2x.config.shrine_buffs) do
		if buff.trait and buff.trait.id == trait_id then return buff end
	end
end

local function all_units()
	local list = wesnoth.units.find_on_map {}
	for i, u in ipairs(wesnoth.units.find_on_recall {}) do table.insert(list, u) end
	return list
end

-- Before 0.6.1 the shrine/gacha backstab used [filter_adjacent] adjacent="opposite", which is not a
-- valid direction, so it never triggered. Re-apply the trait so the unit gets the working special.
local function repair_backstab()
	local buff = find_buff("wc2x_backstab")
	if not buff then return end
	for i, u in ipairs(all_units()) do
		if u:matches { wml.tag.filter_wml { wml.tag.modifications { wml.tag.trait { id = "wc2x_backstab" } } } }
			and wml.tostring(u.__cfg):find('adjacent="opposite"', 1, true) then
			u:remove_modifications({ id = "wc2x_backstab" }, "trait")
			u:add_modification("trait", buff.trait)
		end
	end
end

-- 0.15.0 replaced the Scout Network upgrade with Quartermaster: carry each purchase over 1:1
local function convert_scout_network()
	local converted = false
	for i, side in ipairs(wesnoth.sides) do
		local scouts = side.variables["wc2x_upgrades.vision_radius"]
		if scouts and scouts > 0 then
			side.variables["wc2x_upgrades.quartermaster"] = (side.variables["wc2x_upgrades.quartermaster"] or 0) + scouts
			side.variables["wc2x_upgrades.vision_radius"] = nil
			converted = true
		end
	end
	-- recall costs are otherwise only refreshed when a map is won
	if converted then wesnoth.wml_actions.wc2_set_recall_cost {} end
end

-- 0.17.0 retired Thunder Maul and Azure pearl (not_available=retired). Saves made earlier may
-- still hold them in the remaining-pick lists that WC2 persists; strip them so they can't roll.
-- Units already carrying one keep it.
local function strip_retired_artifacts()
	if not wc2_artifacts then return end
	local function strip(get, set)
		local value = get()
		if value == nil or value == "" then return end
		local kept = {}
		for _i, id in ipairs(stringx.split(tostring(value))) do
			if not wc2_artifacts.is_retired(tonumber(id)) then table.insert(kept, id) end
		end
		local new_value = table.concat(kept, ",")
		if new_value ~= tostring(value) then set(new_value) end
	end
	local function global(name)
		strip(function() return wml.variables[name] end, function(v) wml.variables[name] = v end)
	end
	global("wc2.random_items")             -- bonus points
	global("wc2_enemy_army.artifacts")     -- enemy items
	for _i, side in ipairs(wesnoth.sides) do
		for _j, name in ipairs({ "wc2.items_left", "wc2.items" }) do  -- invest
			strip(function() return side.variables[name] end, function(v) side.variables[name] = v end)
		end
	end
end

function migrations.init()
	wesnoth.game_events.add_repeating("preload", function()
		repair_backstab()
		convert_scout_network()
		strip_retired_artifacts()
	end)
end

return migrations
