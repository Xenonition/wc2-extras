-- WC2 items still lying on the map at victory are sent to their owner's pending list, which
-- upgrades.place_pending_artifacts delivers next to their castle at the start of the next map.
-- Runs inside the victory event (synced), only for scenarios that have a next map.

local _ = wesnoth.textdomain 'wesnoth-wc'

local carryover = {}

function carryover.sweep()
	local last_side = wml.variables.wc2_highest_player_side or wml.variables.wc2_player_count or 1
	local leaders = {}
	local any_leader = false
	for side_num = 1, last_side do
		local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
		if leader then leaders[side_num] = leader; any_leader = true end
	end
	if not any_leader then return end

	local function nearest_side(x, y)
		local best, best_dist
		for side_num = 1, last_side do
			local l = leaders[side_num]
			if l then
				local d = wesnoth.map.distance_between({ x = x, y = y }, { x = l.x, y = l.y })
				if not best or d < best_dist then best, best_dist = side_num, d end
			end
		end
		return best
	end

	local counts = {}
	local map = wesnoth.current.map
	for x = 1, map.playable_width do
		for y = 1, map.playable_height do
			for i, item in ipairs(wesnoth.interface.get_items(x, y)) do
				local vars = item.variables
				local index = vars and vars.wc2_atrifact_id
				if index then
					local owner = vars.wc2x_owner
					if not (owner and leaders[owner]) then owner = nearest_side(x, y) end
					local side_vars = wesnoth.sides[owner].variables
					local pending = side_vars["wc2x_pending_artifacts"] or ""
					side_vars["wc2x_pending_artifacts"] = pending == "" and tostring(index) or (pending .. "," .. index)
					counts[owner] = (counts[owner] or 0) + 1
				end
			end
		end
	end

	local lines = {}
	for side_num = 1, last_side do
		if counts[side_num] then
			table.insert(lines, string.format(tostring(_ "Player %d: %d item(s)"), side_num, counts[side_num]))
		end
	end
	if #lines > 0 then
		wesnoth.wml_actions.message {
			speaker = "narrator",
			caption = _ "Spoils Recovered",
			message = tostring(_ "Items left on the battlefield have been gathered. They will be waiting at your castle on the next map.") .. "\n\n" .. table.concat(lines, "\n"),
			image = "items/chest-plain-closed.png",
		}
	end
end

return carryover
