local unit_pool = {}

local pools_by_level = {}
local built = false

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
		table.sort(pool)
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

function unit_pool.pick_random(min_level, max_level)
	local pool = unit_pool.get_range(min_level, max_level)
	if #pool == 0 then return nil end
	return pool[mathx.random(#pool)]
end

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
