local unit_pool = {}

-- The pool is built from whatever unit types this machine has loaded, so it can differ between
-- players (another LotI build, an add-on that loads its units in every MP game). Random picks from
-- it therefore go through sample() inside sync_ids(): the acting player's machine rolls and every
-- other machine receives the chosen type ids, instead of each machine rolling on its own list.

local pools_by_level = {}
local built = false

-- byte order, independent of the player's locale (Lua's string < uses strcoll)
local function byte_less(a, b)
	for i = 1, math.min(#a, #b) do
		local ca, cb = a:byte(i), b:byte(i)
		if ca ~= cb then return ca < cb end
	end
	return #a < #b
end

local function build_pools()
	if built then return end
	built = true

	local in_tree = {}
	for id, ut in pairs(wesnoth.unit_types) do
		local adv = ut.advances_to
		if adv and #adv > 0 then
			in_tree[id] = true
			for _, target_id in ipairs(adv) do
				in_tree[target_id] = true
			end
		end
	end

	for id, ut in pairs(wesnoth.unit_types) do
		if in_tree[id] then
			local lv = ut.level
			if not pools_by_level[lv] then
				pools_by_level[lv] = {}
			end
			table.insert(pools_by_level[lv], id)
		end
	end

	for _, pool in pairs(pools_by_level) do
		table.sort(pool, byte_less)
	end
end

function unit_pool.get(level)
	build_pools()
	local pool = pools_by_level[level]
	if not pool then return {} end
	local copy = {}
	for i, v in ipairs(pool) do copy[i] = v end
	return copy
end

function unit_pool.get_range(min_level, max_level)
	build_pools()
	local result = {}
	for lv = min_level, max_level do
		for _, id in ipairs(pools_by_level[lv] or {}) do
			table.insert(result, id)
		end
	end
	return result
end

-- up to @a count random type ids from the level range, optionally only those passing @a filter(id).
-- Rolls on this machine only: call it through sync_ids/synced_sample from synced code.
function unit_pool.sample(min_level, max_level, count, filter)
	local pool = unit_pool.get_range(min_level, max_level)
	mathx.shuffle(pool)
	local result = {}
	for _, id in ipairs(pool) do
		if #result >= count then break end
		if not filter or filter(id) then table.insert(result, id) end
	end
	return result
end

function unit_pool.pick_random(min_level, max_level)
	return unit_pool.sample(min_level, max_level, 1)[1]
end

-- runs @a roll (returns a list of type ids) on the acting side's machine and returns its result on
-- every machine. Outside synced code (e.g. inside a dialog that is already synced) it just rolls.
function unit_pool.sync_ids(roll)
	if wesnoth.current.synced_state ~= "synced" then return roll() end
	local function encode() return { ids = table.concat(roll(), ",") } end
	local res = wesnoth.sync.evaluate_single("unit pool roll", encode, encode)
	return (res.ids or "") ~= "" and stringx.split(res.ids) or {}
end

function unit_pool.synced_sample(min_level, max_level, count, filter)
	return unit_pool.sync_ids(function() return unit_pool.sample(min_level, max_level, count, filter) end)
end

-- "<count>/<hash>" of this machine's whole pool, to spot players whose unit lists differ
function unit_pool.fingerprint()
	build_pools()
	local all = {}
	for _, pool in pairs(pools_by_level) do
		for _, id in ipairs(pool) do table.insert(all, id) end
	end
	table.sort(all, byte_less)
	local h = 0
	for _, id in ipairs(all) do
		for i = 1, #id do h = (h * 31 + id:byte(i)) % 4294967296 end
		h = (h * 31 + 44) % 4294967296
	end
	return string.format("%d/%08x", #all, h)
end

-- at turn 1, compare every machine's pool with side 1's; a mismatch can't desync picks any more,
-- but a hero type missing on one machine would still break that player's game, so say so
wesnoth.game_events.add_repeating("turn 1", function()
	local mine = unit_pool.fingerprint()
	local function send() return { fp = mine } end
	local res = wesnoth.sync.evaluate_single("unit pool check", send, send, 1)
	if res.fp ~= mine then
		wesnoth.interface.add_chat_message("WC3", string.format(
			"Your unit list differs from Player 1's (yours %s, theirs %s). Check that everyone has the same LotI and WC3 versions.",
			mine, tostring(res.fp)))
	end
end)

function unit_pool.level_range_for_scenario(scenario_num)
	if scenario_num >= 4 then
		return 3, 3
	elseif scenario_num >= 3 then
		return 2, 3
	elseif scenario_num >= 2 then
		return 2, 2
	else
		return 1, 2
	end
end

return unit_pool
