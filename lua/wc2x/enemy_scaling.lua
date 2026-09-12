-- WC3 enemy scaling — recruit expansion + assassin spawns

local on_event = wesnoth.game_events.add_repeating

local enemy_scaling = {}
local assassin_counter = 0

function enemy_scaling.init(config)
	enemy_scaling.config = config

	local base_wc2_enemy = wesnoth.wml_actions.wc2_enemy
	wesnoth.wml_actions.wc2_enemy = function(cfg)
		base_wc2_enemy(cfg)
		enemy_scaling.expand_recruits(cfg.side)
		enemy_scaling.apply_ai_personality(cfg.side)
	end

	on_event("recruit", function()
		local unit = wesnoth.units.get(wesnoth.current.event_context.x1, wesnoth.current.event_context.y1)
		if not unit then return end
		if wc2_scenario.is_human_side(unit.side) then return end
		enemy_scaling.maybe_make_assassin(unit)
	end)
end

local function find_types_at_level(base_recruits, level)
	local found = {}
	local visited = {}
	local function walk(type_id)
		if visited[type_id] then return end
		visited[type_id] = true
		local ut = wesnoth.unit_types[type_id]
		if not ut then return end
		if ut.level == level then
			found[type_id] = true
		else
			for _, adv in ipairs(ut.advances_to) do
				walk(adv)
			end
		end
	end
	for _, t in ipairs(base_recruits) do walk(t) end
	local result = {}
	for t in pairs(found) do table.insert(result, t) end
	table.sort(result)
	return result
end

function enemy_scaling.expand_recruits(side_num)
	local config = enemy_scaling.config
	local scenario = wc2_scenario.scenario_num()
	local side = wesnoth.sides[side_num]

	local group_id = side.variables["wc2x_enemy_group"]
	if not group_id then
		local n_groups = wml.variables["wc2_enemy_army.group.length"] or 0
		for g = 0, n_groups - 1 do
			local recruits_str = wml.variables[string.format("wc2_enemy_army.group[%d].recruit", g)] or ""
			local group_recruits = stringx.split(recruits_str)
			local dominated = true
			for _, r in ipairs(group_recruits) do
				local found = false
				for _, sr in ipairs(side.recruit) do
					if sr == r then found = true; break end
				end
				if not found then dominated = false; break end
			end
			if dominated then group_id = g; break end
		end
		if group_id then
			side.variables["wc2x_enemy_group"] = group_id
		end
	end
	if not group_id then return end

	local group = wml.variables[string.format("wc2_enemy_army.group[%d]", group_id)]
	if not group then return end
	local recall = wml.get_child(group, "recall")
	local base_recruits = stringx.split(group.recruit or "")

	local to_add = {}

	for _, tier in ipairs(config.enemy_recruit_tiers or {}) do
		if scenario >= tier.start_scenario then
			local pool = {}
			if recall then
				local explicit = stringx.split(recall["level" .. tier.level] or "")
				for _, t in ipairs(explicit) do
					if not pool[t] then pool[t] = true end
				end
			end
			if not next(pool) then
				local discovered = find_types_at_level(base_recruits, tier.level)
				for _, t in ipairs(discovered) do pool[t] = true end
			end
			local sorted = {}
			for t in pairs(pool) do table.insert(sorted, t) end
			table.sort(sorted)
			mathx.shuffle(sorted)
			for i = 1, math.min(tier.count, #sorted) do
				table.insert(to_add, sorted[i])
			end
		end
	end

	if #to_add > 0 then
		wesnoth.wml_actions.allow_recruit {
			side = side_num,
			type = table.concat(to_add, ","),
		}
		for _, t in ipairs(to_add) do
			wesnoth.add_known_unit(t)
		end
	end
end

function enemy_scaling.maybe_make_assassin(unit)
	local config = enemy_scaling.config
	local scenario = wc2_scenario.scenario_num()
	if scenario < config.assassin_start_scenario then return end

	if mathx.random(100) > config.assassin_chance_pct then return end

	assassin_counter = assassin_counter + 1
	local uid = "wc2x_assassin_" .. assassin_counter
	wesnoth.wml_actions.modify_unit {
		wml.tag.filter { x = unit.x, y = unit.y },
		id = uid,
	}
	unit = wesnoth.units.get(unit.x, unit.y)
	unit.variables["wc2x_assassin"] = true

	local player_count = wml.variables.wc2_player_count or 1
	local closest_leader = nil
	local closest_dist = math.huge
	for s = 1, player_count do
		local leaders = wesnoth.units.find_on_map({ side = s, canrecruit = true })
		for _, leader in ipairs(leaders) do
			local d = wesnoth.map.distance_between(unit, leader)
			if d < closest_dist then
				closest_dist = d
				closest_leader = leader
			end
		end
	end
	if not closest_leader then return end

	local mai_id = "wc2x_assassin_" .. assassin_counter
	wesnoth.wml_actions.micro_ai {
		side = unit.side,
		ai_type = "assassin",
		action = "add",
		ca_id = mai_id,
		wml.tag.filter { id = uid },
		wml.tag.filter_second { side = closest_leader.side, canrecruit = true },
	}

	unit:add_modification("object", {
		id = "wc2x_assassin_overlay",
		wml.tag.effect { apply_to = "overlay", add = "misc/hero-icon.png" },
	})
	unit.variables["wc2x_assassin_target_side"] = closest_leader.side
end

local function rand_float(min, max)
	return min + (mathx.random(1000) - 1) / 999 * (max - min)
end

local function rand_int(min, max)
	return mathx.random(min, max)
end

function enemy_scaling.apply_ai_personality(side_num)
	local ranges = enemy_scaling.config.ai_personality_ranges
	if not ranges then return end

	local grouping_opts = enemy_scaling.config.ai_grouping_options or { "offensive" }
	local grouping = grouping_opts[mathx.random(#grouping_opts)]

	local aggression = rand_float(ranges.aggression[1], ranges.aggression[2])
	local caution = rand_float(ranges.caution[1], ranges.caution[2])
	local village_value = rand_float(ranges.village_value[1], ranges.village_value[2])
	local villages_per_scout = rand_int(ranges.villages_per_scout[1], ranges.villages_per_scout[2])
	local leader_aggression = rand_float(ranges.leader_aggression[1], ranges.leader_aggression[2])
	local scout_village_targeting = rand_int(ranges.scout_village_targeting[1], ranges.scout_village_targeting[2])

	local save_ranges = enemy_scaling.config.ai_save_gold_ranges
	local save_active = save_ranges and rand_int(save_ranges.active[1], save_ranges.active[2]) or 0
	local save_begin = save_ranges and rand_float(save_ranges.save_begin[1], save_ranges.save_begin[2]) or 1.5
	local save_end = save_ranges and rand_float(save_ranges.save_end[1], save_ranges.save_end[2]) or 1.1

	local recruit_ranges = enemy_scaling.config.ai_recruitment_ranges
	local recruit_diversity = recruit_ranges and rand_float(recruit_ranges.recruitment_diversity[1], recruit_ranges.recruitment_diversity[2]) or 2.0
	local recruit_randomness = recruit_ranges and rand_int(recruit_ranges.recruitment_randomness[1], recruit_ranges.recruitment_randomness[2]) or 50

	local side = wesnoth.sides[side_num]
	side.variables["wc2x_ai_aggression"] = string.format("%.2f", aggression)
	side.variables["wc2x_ai_caution"] = string.format("%.2f", caution)
	side.variables["wc2x_ai_village_value"] = string.format("%.1f", village_value)
	side.variables["wc2x_ai_villages_per_scout"] = villages_per_scout
	side.variables["wc2x_ai_leader_aggression"] = string.format("%.1f", leader_aggression)
	side.variables["wc2x_ai_scout_village_targeting"] = scout_village_targeting
	side.variables["wc2x_ai_grouping"] = grouping
	side.variables["wc2x_ai_save_begin"] = string.format("%.2f", save_begin)
	side.variables["wc2x_ai_save_end"] = string.format("%.2f", save_end)
	side.variables["wc2x_ai_recruit_diversity"] = string.format("%.1f", recruit_diversity)
	side.variables["wc2x_ai_recruit_randomness"] = recruit_randomness

	wesnoth.wml_actions.modify_side {
		side = side_num,
		wml.tag.ai {
			aggression = aggression,
			caution = caution,
			village_value = village_value,
			villages_per_scout = villages_per_scout,
			leader_aggression = leader_aggression,
			scout_village_targeting = scout_village_targeting,
			grouping = grouping,
			recruitment_diversity = recruit_diversity,
			recruitment_randomness = recruit_randomness,
			wml.tag.recruitment_save_gold {
				active = save_active,
				begin = save_begin,
				["end"] = save_end,
			},
		},
	}
end

return enemy_scaling
