-- WC3 Final Boss — spawns after all regular leaders die on scenario 5

local on_event = wesnoth.game_events.add_repeating
local _ = wesnoth.textdomain "wesnoth-wc"

local boss = {}

local BOSS_TITLES = {
	_ "the Worldbreaker",
	_ "the Conqueror",
	_ "the Undying",
	_ "the Dread Sovereign",
	_ "Bane of Empires",
	_ "the Last Warden",
	_ "Scourge of the Coast",
	_ "the Eternal",
}

local cached_lv3_pool = nil
local function get_lv3_pool()
	if cached_lv3_pool then return cached_lv3_pool end
	cached_lv3_pool = {}
	for id, ut in pairs(wesnoth.unit_types) do
		if ut.level == 3 then
			table.insert(cached_lv3_pool, id)
		end
	end
	table.sort(cached_lv3_pool)
	return cached_lv3_pool
end

local cached_flyer_pool = nil
local function get_flyer_pool()
	if cached_flyer_pool then return cached_flyer_pool end
	cached_flyer_pool = {}
	for id, ut in pairs(wesnoth.unit_types) do
		if ut.level >= 1 then
			local mt = tostring(ut.__cfg.movement_type or "")
			if mt:find("fly") then
				table.insert(cached_flyer_pool, id)
			end
		end
	end
	table.sort(cached_flyer_pool)
	return cached_flyer_pool
end

local function advance_type_to_max(type_id, max_level)
	local current = type_id
	for _ = 1, 10 do
		local ut = wesnoth.unit_types[current]
		if not ut or ut.level >= max_level or #ut.advances_to == 0 then break end
		local candidates = {}
		for _, adv in ipairs(ut.advances_to) do
			local at = wesnoth.unit_types[adv]
			if at and at.level > ut.level then
				table.insert(candidates, adv)
			end
		end
		if #candidates == 0 then break end
		current = candidates[mathx.random(#candidates)]
	end
	return current
end

local function pick_boss_type()
	local pool = get_lv3_pool()
	if #pool == 0 then return "Ancient Lich" end
	local base = pool[mathx.random(#pool)]
	return advance_type_to_max(base, 6)
end

local ARENA_KEEP = "Kud"
local ARENA_CASTLE = "Cd"
local ARENA_RING = "Qxu"
local ARENA_RING_CLEARED = "Rr"

local ARMY_COUNT = 13
local FLYER_COUNT = 10

local arena_center = nil
local boss_spawned = false
local boss_side_num = nil
local boss_unit_id = nil
local function get_hex_ring(cx, cy, target_dist)
	if target_dist == 0 then
		return { [cx .. "," .. cy] = { x = cx, y = cy } }
	end
	local visited = { [cx .. "," .. cy] = true }
	local frontier = { { x = cx, y = cy } }
	for d = 1, target_dist do
		local next_frontier = {}
		for _, hex in ipairs(frontier) do
			local adj = { wesnoth.map.get_adjacent_hexes(hex.x, hex.y) }
			for _, h in ipairs(adj) do
				local key = h.x .. "," .. h.y
				if not visited[key] then
					visited[key] = true
					table.insert(next_frontier, h)
				end
			end
		end
		frontier = next_frontier
	end
	local result = {}
	for _, h in ipairs(frontier) do
		result[h.x .. "," .. h.y] = h
	end
	return result
end

-- sorted: pairs() order over string keys differs between clients, and callers shuffle this list
local function ring_to_list(ring)
	local list = {}
	for _, h in pairs(ring) do
		table.insert(list, h)
	end
	table.sort(list, function(a, b)
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)
	return list
end

-- Arena site: best spot within ARENA_SEARCH_RADIUS of the map centre whose footprint covers
-- no keep or leader, preferring few villages/items/units/water. Ties break by distance, then x/y,
-- so every client picks the same hex.
local ARENA_RADIUS = 3
local ARENA_SEARCH_RADIUS = 6
local ARENA_FOOTPRINT = 37 -- hexes within distance 3

local function choose_arena_center(mx, my)
	local best, best_score, best_dist
	for i, c in ipairs(wesnoth.map.find { x = mx, y = my, radius = ARENA_SEARCH_RADIUS }) do
		local area = wesnoth.map.find { x = c.x, y = c.y, radius = ARENA_RADIUS }
		local ok = #area == ARENA_FOOTPRINT
		local score = 0
		for j, h in ipairs(area) do
			if not ok then break end
			local terr = tostring(wesnoth.current.map[h])
			local u = wesnoth.units.get(h.x, h.y)
			if terr:match("^K") or terr:match("%^K") or (u and u.canrecruit) then
				ok = false
			else
				if terr:match("%^V") then score = score + 10 end
				if #wesnoth.interface.get_items(h.x, h.y) > 0 then score = score + 10 end
				if u then score = score + 3 end
				if terr:match("^W") or terr:match("^S") or terr:match("^Q") or terr:match("^X") then
					score = score + 1
				end
			end
		end
		if ok then
			local dist = wesnoth.map.distance_between({ x = mx, y = my }, c)
			score = score + dist * 2
			local better = not best or score < best_score
				or (score == best_score and dist < best_dist)
				or (score == best_score and dist == best_dist and (c.x < best.x or (c.x == best.x and c.y < best.y)))
			if better then best, best_score, best_dist = c, score, dist end
		end
	end
	if not best then return mx, my end
	return best.x, best.y
end

-- Move units standing in the footprint to the nearest free hex outside it, so nothing is
-- trapped behind the chasm ring or blocks the boss's spawn hexes
local function evacuate_arena(cx, cy)
	local inside = wesnoth.units.find_on_map {
		wml.tag.filter_location { x = cx, y = cy, radius = ARENA_RADIUS },
	}
	if #inside == 0 then return end
	table.sort(inside, function(a, b)
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)
	local outside = wesnoth.map.find {
		x = cx, y = cy, radius = ARENA_RADIUS + 5,
		wml.tag["not"] { x = cx, y = cy, radius = ARENA_RADIUS },
	}
	local taken = {}
	for i, u in ipairs(inside) do
		local best, best_dist
		for j, h in ipairs(outside) do
			local key = h.x .. "," .. h.y
			if not taken[key] and not wesnoth.units.get(h.x, h.y)
				and #wesnoth.interface.get_items(h.x, h.y) == 0
				and wesnoth.units.movement_on(u, { x = h.x, y = h.y }) < 99 then
				local d = wesnoth.map.distance_between({ x = u.x, y = u.y }, h)
				if not best or d < best_dist then best, best_dist = h, d end
			end
		end
		if best then
			taken[best.x .. "," .. best.y] = true
			u:to_map(best.x, best.y)
		end
	end
end

function boss.place_arena()
	local scenario_num = wml.variables["wc2_scenario"] or 1
	if scenario_num ~= 5 then return end

	boss_side_num = wml.variables["wc2x_boss_side"]
	if not boss_side_num then return end

	local map_w = wesnoth.current.map.playable_width
	local map_h = wesnoth.current.map.playable_height
	local border = wesnoth.current.map.border_size or 1
	local cx, cy = choose_arena_center(math.floor(map_w / 2) + border, math.floor(map_h / 2) + border)
	evacuate_arena(cx, cy)

	arena_center = { cx, cy }

	wesnoth.current.map[{cx, cy}] = ARENA_KEEP

	local ring1 = get_hex_ring(cx, cy, 1)
	for _, hex in pairs(ring1) do
		wesnoth.current.map[hex] = ARENA_CASTLE
	end

	local ring2 = get_hex_ring(cx, cy, 2)
	for _, hex in pairs(ring2) do
		wesnoth.current.map[hex] = ARENA_CASTLE
	end

	local ring3 = get_hex_ring(cx, cy, 3)
	for _, hex in pairs(ring3) do
		wesnoth.current.map[hex] = ARENA_RING
	end

	wml.variables["wc2x_arena_x"] = cx
	wml.variables["wc2x_arena_y"] = cy
end

local function clear_arena_ring()
	if not arena_center then
		local ax = wml.variables["wc2x_arena_x"]
		local ay = wml.variables["wc2x_arena_y"]
		if ax and ay then arena_center = { ax, ay } end
	end
	if not arena_center then return end
	local cx, cy = arena_center[1], arena_center[2]

	local ring3 = get_hex_ring(cx, cy, 3)
	for _, hex in pairs(ring3) do
		wesnoth.current.map[hex] = ARENA_RING_CLEARED
	end
end

local function lift_arena_fog()
	if not arena_center then return end
	local nplayers = wml.variables["wc2_player_count"] or 1
	for side_num = 1, nplayers do
		wesnoth.wml_actions.lift_fog {
			wml.tag.filter_side { side = side_num },
			x = arena_center[1], y = arena_center[2],
			radius = 7,
			multiturn = true,
		}
	end
end

local EDGE_DEPTH = 3

local function find_edge_hexes(count)
	local map_w = wesnoth.current.map.playable_width
	local map_h = wesnoth.current.map.playable_height
	local border = wesnoth.current.map.border_size or 1
	local x_min = border + 1
	local x_max = map_w + border
	local y_min = border + 1
	local y_max = map_h + border
	local seen = {}
	local bands = { {}, {}, {}, {} }
	for d = 0, EDGE_DEPTH - 1 do
		for x = x_min + d, x_max - d do
			local hexes = { { x, y_min + d }, { x, y_max - d } }
			for bi, hex in ipairs(hexes) do
				local key = hex[1] .. "," .. hex[2]
				if not seen[key] then
					seen[key] = true
					table.insert(bands[bi], hex)
				end
			end
		end
		for y = y_min + d + 1, y_max - d - 1 do
			local hexes = { { x_min + d, y }, { x_max - d, y } }
			for bi, hex in ipairs(hexes) do
				local key = hex[1] .. "," .. hex[2]
				if not seen[key] then
					seen[key] = true
					table.insert(bands[bi + 2], hex)
				end
			end
		end
	end
	local filtered_sides = {}
	for _, band in ipairs(bands) do
		local walkable = {}
		for _, hex in ipairs(band) do
			local terr = tostring(wesnoth.current.map[hex])
			if terr and not terr:match("[XQ]") and not terr:match("^Mv") then
				table.insert(walkable, hex)
			end
		end
		if #walkable > 0 then
			mathx.shuffle(walkable)
			table.insert(filtered_sides, walkable)
		end
	end
	if #filtered_sides == 0 then return {} end
	local result = {}
	local per_side = math.ceil(count / #filtered_sides)
	for _, walkable in ipairs(filtered_sides) do
		for i = 1, math.min(per_side, #walkable) do
			table.insert(result, walkable[i])
		end
	end
	mathx.shuffle(result)
	while #result > count do
		table.remove(result)
	end
	return result
end


local function spawn_boss()
	if boss_spawned then return end
	boss_spawned = true

	if not boss_side_num then
		boss_side_num = wml.variables["wc2x_boss_side"]
	end
	if not arena_center then
		local ax = wml.variables["wc2x_arena_x"]
		local ay = wml.variables["wc2x_arena_y"]
		if ax and ay then arena_center = { ax, ay } end
	end
	if not boss_side_num or not arena_center then return end

	clear_arena_ring()
	lift_arena_fog()

	local cx, cy = arena_center[1], arena_center[2]

	local boss_type = pick_boss_type()
	local title = BOSS_TITLES[mathx.random(#BOSS_TITLES)]

	local unit_cfg = {
		x = cx, y = cy,
		type = boss_type,
		side = boss_side_num,
		canrecruit = true,
		generate_name = true,
	}
	if wc2_heroes.trait_heroic then
		unit_cfg[1] = wml.tag.modifications {
			wml.tag.trait(wc2_heroes.trait_heroic),
		}
	end
	wesnoth.wml_actions.unit(unit_cfg)

	local boss_unit = wesnoth.units.find_on_map({ side = boss_side_num, canrecruit = true })[1]
	if boss_unit then
		boss_unit:add_modification("object", {
			id = "wc2x_boss_buffs",
			wml.tag.effect { apply_to = "new_ability",
				wml.tag.abilities { wml.tag.regenerate {
					id = "regenerates", name = "regenerates",
					description = "This unit restores 8 HP at the start of each turn.",
					value = 8,
				}},
			},
			wml.tag.effect { apply_to = "new_ability",
				wml.tag.abilities { wml.tag.skirmisher {
					id = "skirmisher", name = "skirmisher",
					description = "This unit's movement is not slowed by enemy zones of control.",
				}},
			},
			wml.tag.effect {
				apply_to = "hitpoints",
				increase_total = "50%",
				heal_full = true,
			},
		})
		boss_unit.name = boss_unit.name .. " " .. title
		boss_unit.hitpoints = boss_unit.max_hitpoints
		boss_unit_id = boss_unit.id
		wml.variables["wc2x_boss_id"] = boss_unit.id
		wml.variables["wc2x_boss_name"] = tostring(boss_unit.name)
	end

	wesnoth.sides[boss_side_num].hidden = false

	local lv3 = get_lv3_pool()
	local troop_hexes = ring_to_list(get_hex_ring(cx, cy, 1))
	for _, h in ipairs(ring_to_list(get_hex_ring(cx, cy, 2))) do
		table.insert(troop_hexes, h)
	end
	mathx.shuffle(troop_hexes)
	for i = 1, math.min(ARMY_COUNT, #troop_hexes) do
		local loc = troop_hexes[i]
		local troop_type = lv3[mathx.random(#lv3)]
		wesnoth.wml_actions.unit {
			x = loc.x, y = loc.y,
			type = troop_type,
			side = boss_side_num,
			generate_name = true,
		}
	end

	local flyers = get_flyer_pool()
	local edge_hexes = find_edge_hexes(FLYER_COUNT)

	for i = 1, #edge_hexes do
		local flyer_type = flyers[mathx.random(#flyers)]
		local hex = edge_hexes[i]
		wesnoth.wml_actions.unit {
			x = hex[1], y = hex[2],
			type = flyer_type,
			side = boss_side_num,
			generate_name = true,
		}
		local flyer = wesnoth.units.get(hex[1], hex[2])
		if flyer then
			flyer:add_modification("object", {
				id = "wc2x_boss_flyer_swift",
				wml.tag.effect {
					apply_to = "movement_costs",
					replace = true,
					wml.tag.movement_costs {
						flat = 1, castle = 1, village = 1, forest = 1,
						hills = 1, mountains = 1, swamp = 1, sand = 1,
						cave = 1, shallow_water = 1, deep_water = 1,
						reef = 1, frozen = 1, fungus = 1, unwalkable = 1,
					},
				},
				wml.tag.effect {
					apply_to = "movement",
					increase = 3,
				},
			})
			flyer.moves = flyer.max_moves
		end
	end

	wesnoth.wml_actions.music {
		name = "the_king_is_dead.ogg",
		immediate = true,
		append = false,
	}

	wesnoth.wml_actions.scroll_to { x = cx, y = cy }

	wesnoth.wml_actions.message {
		side = boss_side_num,
		canrecruit = true,
		message = _ "You thought this land was yours? I have watched your petty conquests from my throne. Now face a TRUE ruler!",
	}

	wesnoth.wml_actions.music {
		name = "battle-epic.ogg",
		immediate = true,
		append = false,
	}
	wesnoth.wml_actions.music {
		name = "the_dangerous_symphony.ogg",
		append = true,
	}
	wesnoth.wml_actions.music {
		name = "weight_of_revenge.ogg",
		append = true,
	}

	wesnoth.wml_actions.wc2_objectives {}
end

local function check_regular_leaders_dead(dying_x, dying_y)
	local scenario_num = wml.variables["wc2_scenario"] or 1
	if scenario_num ~= 5 then return false end
	if boss_spawned then return false end

	local nplayers = wml.variables["wc2_player_count"] or 1
	local first_enemy = math.max(nplayers, 3) + 1
	local n_enemy_sides = 4
	for i = first_enemy, first_enemy + n_enemy_sides - 1 do
		local leaders = wesnoth.units.find_on_map({ side = i, canrecruit = true })
		for _, l in ipairs(leaders) do
			if l.x ~= dying_x or l.y ~= dying_y then return false end
		end
		local commanders = wesnoth.units.find_on_map({ side = i, role = "commander", canrecruit = false })
		if #commanders > 0 then return false end
	end
	return true
end

local function restore_state()
	boss_side_num = wml.variables["wc2x_boss_side"]
	local ax = wml.variables["wc2x_arena_x"]
	local ay = wml.variables["wc2x_arena_y"]
	if ax and ay then arena_center = { ax, ay } end
	local bid = wml.variables["wc2x_boss_id"]
	if bid then
		boss_unit_id = bid
		boss_spawned = true
	end
end

function boss.init(config)
	on_event("preload", function()
		restore_state()
	end)

	on_event("prestart", function()
		boss.place_arena()
	end)

	on_event("die", function()
		local scenario_num = wml.variables["wc2_scenario"] or 1
		if scenario_num ~= 5 then return end

		local ec = wesnoth.current.event_context
		local dying = wesnoth.units.get(ec.x1, ec.y1)
		if not dying then return end

		if dying.canrecruit and not boss_spawned then
			if check_regular_leaders_dead(ec.x1, ec.y1) then
				spawn_boss()
			end
		end

		if boss_spawned then
			local bid = boss_unit_id or wml.variables["wc2x_boss_id"]
			if bid and dying.id == bid then
				local boss_name = wml.variables["wc2x_boss_name"] or "the Final Boss"
				wesnoth.wml_actions.message {
					side = "1",
					canrecruit = true,
					message = boss_name .. _ " is slain! Against all odds, we have prevailed.",
				}
				wesnoth.wml_actions.message {
					side = "1,2,3",
					canrecruit = false,
					message = _ "From a handful of soldiers to conquerors of an entire world. What a journey it has been.",
				}
				wesnoth.audio.play("ambient/ship.ogg")
				wesnoth.wml_actions.endlevel {
					result = "victory",
					carryover_percentage = 0,
					carryover_add = false,
					carryover_report = false,
					music = "sad.ogg",
					end_text = _ "The End",
					next_scenario = "",
				}
			end
		end
	end)
end

function boss.is_boss_phase()
	return boss_spawned
end

function boss.get_boss_side()
	return boss_side_num
end

return boss
