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

function migrations.init()
	wesnoth.game_events.add_repeating("preload", function()
		repair_backstab()
		convert_scout_network()
	end)
end

return migrations
