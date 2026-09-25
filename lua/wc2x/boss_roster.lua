-- WC3 final boss roster: one signature mechanic + one phase change per boss.
-- final_boss.lua owns the arena, trigger, spawn and victory; this file owns what makes each boss different.
-- All state lives on the map (unit variables) or in wml.variables, so it survives save/load.

local _ = wesnoth.textdomain "wesnoth-wc"

local roster = {}

local BLOCKED = "X*,Q*,*^X*"

local function sorted_by_xy(list)
	table.sort(list, function(a, b)
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)
	return list
end

local function free_hex(loc)
	return not wesnoth.units.get(loc.x, loc.y) and #wesnoth.interface.get_items(loc.x, loc.y) == 0
end

local function boss_unit()
	local id = wml.variables["wc2x_boss_id"]
	return id and wesnoth.units.find_on_map({ id = id })[1]
end

local function player_sides_last()
	return wml.variables.wc2_highest_player_side or wml.variables.wc2_player_count or 1
end

-- Creates a unit off-map and puts it on the nearest passable free hex to (x, y) within rmin..rmax
local function spawn_near(type_id, side, x, y, rmin, rmax, cfg)
	local u = wesnoth.units.create(cfg or { type = type_id, side = side, generate_name = true, random_traits = true })
	local candidates = wesnoth.map.find {
		wml.tag["and"] { x = x, y = y, radius = rmax },
		wml.tag["not"] { terrain = BLOCKED },
	}
	local list = {}
	for i, loc in ipairs(candidates) do
		local d = wesnoth.map.distance_between({ x = x, y = y }, loc)
		if d >= rmin and free_hex(loc) and wesnoth.units.movement_on(u, { x = loc.x, y = loc.y }) < 99 then
			table.insert(list, { x = loc.x, y = loc.y, d = d })
		end
	end
	table.sort(list, function(a, b)
		if a.d ~= b.d then return a.d < b.d end
		if a.x ~= b.x then return a.x < b.x end
		return a.y < b.y
	end)
	if not list[1] then return nil end
	u:to_map(list[1].x, list[1].y)
	return u
end

-- Picks up to `count` hexes from `candidates` (already filtered) at least `spacing` apart; random but synced
local function pick_spread(candidates, count, spacing)
	sorted_by_xy(candidates)
	mathx.shuffle(candidates)
	local picked = {}
	for i, c in ipairs(candidates) do
		local ok = true
		for j, p in ipairs(picked) do
			if wesnoth.map.distance_between(c, p) < spacing then ok = false; break end
		end
		if ok then
			table.insert(picked, c)
			if #picked >= count then break end
		end
	end
	return picked
end

local function say(boss, message)
	if not boss then return end
	wesnoth.wml_actions.message { id = boss.id, message = message }
end

---------------------------------------------------------------------------
-- The Lich Sovereign — signature: phylacteries; phase: Grave Tide
---------------------------------------------------------------------------
local lich = {
	type = "WC3 Lich Sovereign",
	fallback_name = "Vorthas",
	titles = { _ "the Undying", _ "the Eternal", _ "Keeper of the Grave" },
	army = { "Draug", "Banebow", "Lich", "Death Knight", "Ghast" },
	edge = { "Spectre", "Nightgaunt" },
	edge_swift = true,
	intro = _ "You broke my servants, but you cannot break me. My soul rests where you will never find it.",
}

local PHYLACTERY_TYPE = "WC3 Phylactery"
local PHYLACTERY_COUNT = 3

local function phylacteries_left(exclude_id)
	local n = 0
	for i, u in ipairs(wesnoth.units.find_on_map { type = PHYLACTERY_TYPE }) do
		if u.id ~= exclude_id then n = n + 1 end
	end
	return n
end

function lich.on_spawn(ctx)
	local player_units = wesnoth.units.find_on_map { side = "1-" .. player_sides_last() }
	local candidates = {}
	for i, loc in ipairs(wesnoth.map.find {
		wml.tag["not"] { terrain = BLOCKED .. ",W*,S*,C*,K*,*^C*,*^K*,*^V*" },
	}) do
		if free_hex(loc) and wesnoth.map.distance_between({ x = ctx.cx, y = ctx.cy }, loc) >= 10 then
			local near_player = false
			for j, pu in ipairs(player_units) do
				if wesnoth.map.distance_between({ x = pu.x, y = pu.y }, loc) < 5 then near_player = true; break end
			end
			if not near_player then table.insert(candidates, { x = loc.x, y = loc.y }) end
		end
	end
	local spots = pick_spread(candidates, PHYLACTERY_COUNT, 8)
	if #spots < PHYLACTERY_COUNT then spots = pick_spread(candidates, PHYLACTERY_COUNT, 4) end
	for i, loc in ipairs(spots) do
		wesnoth.wml_actions.unit {
			type = PHYLACTERY_TYPE, side = ctx.side, x = loc.x, y = loc.y,
			name = _ "Phylactery", random_traits = false,
		}
	end
end

function lich.on_phase(ctx)
	say(ctx.boss, _ "Rise, my faithful. Rise and feast!")
	local summons = { "Revenant", "Deathblade", "Bone Shooter", "Wraith" }
	for i = 1, 5 do
		spawn_near(nil, ctx.side, ctx.boss.x, ctx.boss.y, 1, 3, {
			type = summons[mathx.random(#summons)], side = ctx.side,
			generate_name = true, random_traits = true,
		})
	end
end

-- Revive at the arena keep while any phylactery survives. Runs inside the die event, while the
-- dying boss still occupies its hex, so the vacant-hex search never picks that hex.
function lich.on_boss_death(ctx)
	if phylacteries_left() == 0 then return false end
	local dying = ctx.boss
	local cfg = { type = lich.type, side = ctx.side, canrecruit = true, name = dying.name, random_traits = true }
	if wc2_heroes.trait_heroic then
		cfg[1] = wml.tag.modifications { wml.tag.trait(wc2_heroes.trait_heroic) }
	end
	local u = wesnoth.units.create(cfg)
	local x, y = wesnoth.paths.find_vacant_hex(ctx.cx, ctx.cy, u)
	if not x then return false end
	u:to_map(x, y)
	u.hitpoints = math.floor(u.max_hitpoints / 2)
	-- a Lich slain on its own turn must not get a second action that turn
	u.moves = 0
	u.attacks_left = 0
	wml.variables["wc2x_boss_id"] = u.id
	wesnoth.wml_actions.message {
		id = u.id,
		message = string.format(tostring(_ "Fools. While my phylacteries endure, so do I. (%d remaining)"), phylacteries_left()),
	}
	return true
end

function lich.on_unit_death(ctx, dying)
	if dying.type ~= PHYLACTERY_TYPE then return end
	local left = phylacteries_left(dying.id)
	if left == 0 then
		say(boss_unit(), _ "No... NO! My last vessel! I am... mortal...")
	else
		say(boss_unit(), string.format(tostring(_ "You dare shatter my vessel? %d still remain."), left))
	end
	return true
end

function lich.status_text(exclude_id)
	return string.format(tostring(_ "Phylacteries remaining: %d — the Lich rises again while any survives"), phylacteries_left(exclude_id))
end

---------------------------------------------------------------------------
-- The Wyrm of the Last Age — signature: scorching aura; phase: Wrath
---------------------------------------------------------------------------
local wyrm = {
	type = "WC3 Wyrm",
	fallback_name = "Ignaroth",
	titles = { _ "the Worldbreaker", _ "the Ashen Tyrant", _ "Scourge of the Coast" },
	army = { "Drake Flameheart", "Drake Enforcer", "Drake Warden", "Drake Blademaster" },
	edge = { "Hurricane Drake", "Inferno Drake" },
	edge_swift = true,
	intro = _ "Little conquerors, crawling across my world. Come closer. Burn.",
}

local SCORCH_DAMAGE = 8

function wyrm.on_turn_refresh(ctx, side_num)
	if side_num > player_sides_last() then return end
	wesnoth.wml_actions.harm_unit {
		wml.tag.filter {
			side = side_num,
			wml.tag.filter_adjacent { id = ctx.boss.id },
		},
		amount = SCORCH_DAMAGE,
		damage_type = "fire",
		kill = false,
		fire_event = false,
		experience = false,
		animate = false,
	}
end

function wyrm.on_phase(ctx)
	say(ctx.boss, _ "ENOUGH! You will know the full wrath of the last dragon!")
	ctx.boss:add_modification("object", {
		id = "wc3_wyrm_wrath",
		wml.tag.effect { apply_to = "attack", increase_attacks = 1 },
		wml.tag.effect { apply_to = "movement", increase = 2 },
	})
end

function wyrm.status_text()
	if wml.variables["wc2x_boss_phase_done"] then
		return tostring(_ "The Wyrm is enraged. Its scorching aura burns every adjacent enemy each turn.")
	end
	return tostring(_ "The Wyrm's scorching aura burns every adjacent enemy each turn.")
end

---------------------------------------------------------------------------
-- The Usurper — signature: lieutenants (royal shield); phase: The Crown's Guard
---------------------------------------------------------------------------
local usurper = {
	type = "WC3 Usurper",
	fallback_name = "Aldric",
	titles = { _ "the Conqueror", _ "the Pretender", _ "Bane of Empires" },
	army = { "Royal Guard", "Halberdier", "Iron Mauler", "Master Bowman", "Silver Mage" },
	edge = { "Cavalier", "Grand Knight" },
	edge_swift = false,
	intro = _ "Kneel before your rightful king. My officers have sworn their lives to me — and so shall you.",
}

local LIEUTENANTS = { "General", "Arch Mage", "Master Bowman" }
local SHIELD_PER_LIEUTENANT = 25
local SHIELD_ID = "wc3_royal_shield"

local function lieutenants_left(exclude_id)
	local n = 0
	for i, u in ipairs(wesnoth.units.find_on_map { side = wml.variables["wc2x_boss_side"] }) do
		if u.variables.wc3_lieutenant and u.id ~= exclude_id then n = n + 1 end
	end
	return n
end

local function update_shield(boss, exclude_id)
	if not boss then return end
	boss:remove_modifications({ id = SHIELD_ID }, "object")
	local n = lieutenants_left(exclude_id)
	if n == 0 then return end
	local r = -SHIELD_PER_LIEUTENANT * n
	boss:add_modification("object", {
		id = SHIELD_ID,
		wml.tag.effect {
			apply_to = "resistance", replace = false,
			wml.tag.resistance { blade = r, pierce = r, impact = r, fire = r, cold = r, arcane = r },
		},
	})
end

function usurper.on_spawn(ctx)
	local candidates = {}
	for i, loc in ipairs(wesnoth.map.find {
		-- radius inside [and]/[not]: a top-level radius is applied after [not], which emptied this set
		wml.tag["and"] { x = ctx.cx, y = ctx.cy, radius = 7 },
		wml.tag["not"] { x = ctx.cx, y = ctx.cy, radius = 4 },
		wml.tag["not"] { terrain = BLOCKED .. ",W*,S*" },
	}) do
		if free_hex(loc) then table.insert(candidates, { x = loc.x, y = loc.y }) end
	end
	local spots = pick_spread(candidates, #LIEUTENANTS, 4)
	for i, loc in ipairs(spots) do
		wesnoth.wml_actions.unit {
			type = LIEUTENANTS[i], side = ctx.side, x = loc.x, y = loc.y,
			generate_name = true, random_traits = true,
			wml.tag.variables { wc3_lieutenant = true },
			wml.tag.modifications {
				wml.tag.object {
					id = "wc3_lieutenant_overlay",
					wml.tag.effect { apply_to = "overlay", add = "misc/hero-icon.png" },
				},
			},
		}
	end
	update_shield(ctx.boss)
end

function usurper.on_unit_death(ctx, dying)
	if not dying.variables.wc3_lieutenant then return end
	update_shield(boss_unit(), dying.id)
	local left = lieutenants_left(dying.id)
	if left == 0 then
		say(boss_unit(), _ "Traitors and corpses, all of them! Then I will defend my crown myself!")
	else
		say(boss_unit(), string.format(tostring(_ "You will pay for that. %d of my officers still stand."), left))
	end
	return true
end

function usurper.on_phase(ctx)
	say(ctx.boss, _ "Guards! To your king! We end this now!")
	for i = 1, 4 do
		spawn_near("Royal Guard", ctx.side, ctx.boss.x, ctx.boss.y, 1, 3)
	end
	-- nudge only: the default AI decides, these make it willing to leave the keep and fight
	wesnoth.wml_actions.modify_side {
		side = ctx.side,
		wml.tag.ai { leader_ignores_keep = true, leader_aggression = 1.0, passive_leader = false },
	}
end

function usurper.status_text(exclude_id)
	local n = lieutenants_left(exclude_id)
	return string.format(tostring(_ "Lieutenants alive: %d — each gives the Usurper +%d%% resistance"), n, SHIELD_PER_LIEUTENANT)
end

---------------------------------------------------------------------------

roster.bosses = { lich = lich, usurper = usurper, wyrm = wyrm }
local KINDS = { "lich", "usurper", "wyrm" }

roster.kinds = KINDS

-- The debug panel can force a kind for testing
function roster.pick()
	local forced = wml.variables["wc2x_boss_force"]
	if forced and roster.bosses[forced] then return forced end
	return KINDS[mathx.random(#KINDS)]
end

function roster.get(kind)
	return roster.bosses[kind]
end

roster.spawn_near = spawn_near

return roster
