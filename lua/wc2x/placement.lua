-- Shared "put something next to the leader" logic for items and spawned units

local placement = {}

local SEARCH_RADIUS = 4
local BLOCKED_TERRAIN = "X*,Q*,*^X*,Wo*"

local function is_castle(loc)
	return tostring(wesnoth.current.map[loc]):match("[CK]") ~= nil
end

-- Free hexes around the leader: castle hexes first, then by distance, then x/y (deterministic for MP)
function placement.hexes_near(leader)
	local candidates = wesnoth.map.find {
		-- radius goes inside [and]: at top level it is applied after [not] and would re-add blocked hexes
		wml.tag["and"] { x = leader.x, y = leader.y, radius = SEARCH_RADIUS },
		wml.tag["not"] { terrain = BLOCKED_TERRAIN },
	}
	local result = {}
	for i, loc in ipairs(candidates) do
		if not (loc.x == leader.x and loc.y == leader.y)
			and not wesnoth.units.get(loc.x, loc.y)
			and #wesnoth.interface.get_items(loc.x, loc.y) == 0 then
			table.insert(result, {
				x = loc.x, y = loc.y,
				castle = is_castle(loc),
				dist = wesnoth.map.distance_between({ x = leader.x, y = leader.y }, loc),
			})
		end
	end
	table.sort(result, function(a, b)
		if a.castle ~= b.castle then return a.castle end
		if a.dist ~= b.dist then return a.dist < b.dist end
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)
	return result
end

-- Hex for an item drop; `taken` is a set of "x,y" keys already used in this batch
function placement.item_hex(leader, taken)
	for i, loc in ipairs(placement.hexes_near(leader)) do
		local key = loc.x .. "," .. loc.y
		if not taken or not taken[key] then
			if taken then taken[key] = true end
			return loc
		end
	end
end

-- Puts an off-map unit next to the leader (castle first); falls back to the recall list if boxed in
function placement.unit_to_map(unit, leader)
	for i, loc in ipairs(placement.hexes_near(leader)) do
		if wesnoth.units.movement_on(unit, { x = loc.x, y = loc.y }) < 99 then
			unit:to_map(loc.x, loc.y)
			return true
		end
	end
	local x, y = wesnoth.paths.find_vacant_hex(leader.x, leader.y, unit)
	if x then
		unit:to_map(x, y)
		return true
	end
	unit:to_recall()
	return false
end

return placement
