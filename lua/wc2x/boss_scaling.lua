-- Adaptive final boss army: sized and buffed from the players' own strength when the boss spawns.
--   army size  <- combined recruit value of every player unit (map + recall list)
--   escort buffs <- how far the players' key units are above their unit type (source-agnostic:
--                   traits, shrines, gacha, WC2 and LotI items all show up as plain stat changes)
--   boss HP    <- enemies killed by players over the whole campaign
-- Everything here is computed from synced game state, so all clients get the same result.

local _ = wesnoth.textdomain "wesnoth-wc"

local scaling = {}

local KILLS_VAR = "wc2x_campaign_kills"
local RESULT_VAR = "wc2x_boss_scaling"
local DAMAGE_TYPES = { "blade", "pierce", "impact", "fire", "cold", "arcane" }

scaling.GOLD_FLOOR = 1500
scaling.ARENA = { base = 13, gold_step = 300, cap = 18 } -- rings 1-2 around the boss hold 18 hexes
scaling.EDGE = { base = 10, gold_step = 150, cap = 20 }
scaling.KEY_UNITS_PER_PLAYER = 5
scaling.BONUS_THRESHOLD = 4 -- below this key-unit score the escort gets no buffs
scaling.BONUS_STEP = 2      -- then +1 buff per this many points
scaling.BONUS_CAP = 4
scaling.KILLS_PER_STEP = 50
scaling.HP_PCT_PER_STEP = 5
scaling.HP_PCT_CAP = 100

local function player_sides()
	local list = {}
	for _, s in ipairs(wesnoth.sides) do
		if s.team_name == "wc2_player" then table.insert(list, s.side) end
	end
	return list
end

local function units_of(side)
	local list = wesnoth.units.find_on_map({ side = side })
	for _, u in ipairs(wesnoth.units.find_on_recall({ side = side })) do
		table.insert(list, u)
	end
	return list
end

-- named abilities only: our tiered buffs and LotI split one visible ability into several hidden
-- entries, and stealth (hides) doesn't make a unit any stronger in a fight
local function named_abilities(cfg)
	local set = {}
	local abilities = wml.get_child(cfg, "abilities")
	for _, ab in ipairs(abilities or {}) do
		if ab[1] ~= "hides" and ab[2].id and (ab[2].name or "") ~= "" then set[ab[2].id] = true end
	end
	return set
end

local function attack_profile(u)
	local best, names, specials = 0, {}, {}
	for _, a in ipairs(u.attacks) do
		best = math.max(best, a.damage * a.number)
		names[a.name] = true
		for _, sp in ipairs(a.specials or {}) do
			if sp[2].id and (sp[2].name or "") ~= "" then specials[sp[1] .. ":" .. sp[2].id] = true end
		end
	end
	return best, names, specials
end

-- the unit type as a fresh, trait-less unit: resistances come from the movetype, which unit_type
-- doesn't expose, and comparing unit to unit keeps both sides measured the same way
local base_cache = {}
local function base_of(type_id)
	if base_cache[type_id] == nil then
		local ok, b = pcall(wesnoth.units.create, { type = type_id, random_traits = false, generate_name = false })
		if ok and b then
			local best, names, specials = attack_profile(b)
			local res = {}
			for _, t in ipairs(DAMAGE_TYPES) do res[t] = b:resistance_against(t) end
			base_cache[type_id] = {
				hp = b.max_hitpoints, moves = b.max_moves, best = best, names = names,
				specials = specials, abilities = named_abilities(b.__cfg), res = res,
			}
		else
			base_cache[type_id] = false
		end
	end
	return base_cache[type_id]
end

-- How far a unit is above its own type, in "buff points":
--   +1 per +20% max HP, +1 per +25% best attack (damage x strikes), +1 per new named special,
--   +1 per new attack, +1 per new named ability, +1 per +10% average resistance, +0.5 per move
function scaling.unit_boost(u)
	local b = base_of(u.type)
	if not b or b.hp <= 0 then return 0 end
	local cfg = u.__cfg
	local score = math.max(0, (u.max_hitpoints / b.hp - 1) / 0.20)
	local best, names, specials = attack_profile(u)
	if b.best > 0 then score = score + math.max(0, (best / b.best - 1) / 0.25) end
	for k in pairs(specials) do if not b.specials[k] then score = score + 1 end end
	for k in pairs(names) do if not b.names[k] then score = score + 1 end end
	for k in pairs(named_abilities(cfg)) do if not b.abilities[k] then score = score + 1 end end
	local res_gain = 0
	for _, t in ipairs(DAMAGE_TYPES) do res_gain = res_gain + u:resistance_against(t) - b.res[t] end
	score = score + math.max(0, res_gain / #DAMAGE_TYPES / 10)
	score = score + math.max(0, u.max_moves - b.moves) * 0.5
	return score
end

-- key units: the ones a player has invested in — heroic, carrying a WC2 or LotI item, level 2+,
-- or the leader. Plain level-1 recruits only carry faction training, which every player has.
local function is_key_unit(u)
	if u.canrecruit or u.level >= 2 then return true end
	local heroic = wc2_heroes and wc2_heroes.trait_heroic and wc2_heroes.trait_heroic.id or "heroic"
	for _, t in ipairs(u.traits) do
		if t == heroic then return true end
	end
	local mods = wml.get_child(u.__cfg, "modifications")
	for _, obj in ipairs(mods and wml.child_array(mods, "object") or {}) do
		if obj.wc2_atrifact_id or obj.sort then return true end
	end
	return false
end

function scaling.measure()
	local gold, pooled, key_count, detail = 0, {}, 0, {}
	for _, side in ipairs(player_sides()) do
		local keys = {}
		for _, u in ipairs(units_of(side)) do
			gold = gold + u.cost
			if is_key_unit(u) then
				table.insert(keys, { score = scaling.unit_boost(u), name = tostring(u.name), type = u.type })
			end
		end
		table.sort(keys, function(a, b)
			if a.score ~= b.score then return a.score > b.score end
			return a.type < b.type
		end)
		key_count = key_count + #keys
		for i = 1, math.min(scaling.KEY_UNITS_PER_PLAYER, #keys) do
			table.insert(pooled, keys[i].score)
			table.insert(detail, string.format("  side %d: %s (%s) %.1f", side, keys[i].name, keys[i].type, keys[i].score))
		end
	end
	local sum = 0
	for _, s in ipairs(pooled) do sum = sum + s end
	local score = #pooled > 0 and sum / #pooled or 0

	local function size(spec)
		local extra = math.max(0, math.floor((gold - scaling.GOLD_FLOOR) / spec.gold_step))
		return math.min(spec.cap, spec.base + extra)
	end
	local bonuses = 0
	if score >= scaling.BONUS_THRESHOLD then
		bonuses = math.min(scaling.BONUS_CAP, 1 + math.floor((score - scaling.BONUS_THRESHOLD) / scaling.BONUS_STEP))
	end
	local kills = scaling.kills()
	local hp_pct = math.min(scaling.HP_PCT_CAP, math.floor(kills / scaling.KILLS_PER_STEP) * scaling.HP_PCT_PER_STEP)

	return {
		gold = gold, score = score, key_units = key_count,
		arena = size(scaling.ARENA), edge = size(scaling.EDGE),
		bonuses = bonuses, kills = kills, hp_pct = hp_pct,
		detail = table.concat(detail, "\n"),
	}
end

function scaling.kills()
	return wml.variables[KILLS_VAR] or 0
end

-- stored at spawn so the Lich's revival and the debug readout use the same numbers
function scaling.save(result)
	wml.variables[RESULT_VAR] = {
		gold = result.gold, score = result.score, arena = result.arena, edge = result.edge,
		bonuses = result.bonuses, kills = result.kills, hp_pct = result.hp_pct,
	}
end

function scaling.saved()
	return wml.variables[RESULT_VAR]
end

function scaling.apply_boss_hp(u, hp_pct)
	if not u or (hp_pct or 0) <= 0 then return end
	u:add_modification("object", {
		id = "wc2x_boss_slaughter_hp",
		wml.tag.effect { apply_to = "hitpoints", increase_total = hp_pct .. "%" },
	})
end

-- true if any of the buff's effects changes the XP needed to level
local function is_xp_buff(buff)
	if buff.effect and buff.effect.apply_to == "max_experience" then return true end
	for _, child in ipairs(buff.trait or {}) do
		if child[1] == "effect" and child[2].apply_to == "max_experience" then return true end
	end
	return false
end

-- shrine-pool buffs for an escort unit; skips buffs it can't use (XP on a unit that won't level)
-- and ones the shrine would skip too (see poi.buff_is_redundant)
function scaling.buff_escort(u, count)
	if count <= 0 then return end
	local pool = wc2x.config.shrine_buffs
	local exclude = {}
	for _ = 1, count do
		-- re-checked each pick: the buffs already given can make others redundant (regenerates +8 and +4)
		for i, buff in ipairs(pool) do
			if not exclude[i] and (is_xp_buff(buff) or wc2x.poi.buff_is_redundant(u, buff)) then exclude[i] = true end
		end
		local total = 0
		for i, buff in ipairs(pool) do
			if not exclude[i] then total = total + buff.weight end
		end
		if total <= 0 then return end
		local roll, cum = mathx.random(total), 0
		for i, buff in ipairs(pool) do
			if not exclude[i] then
				cum = cum + buff.weight
				if roll <= cum then
					exclude[i] = true
					if buff.trait then
						u:add_modification("trait", buff.trait)
					else
						u:add_modification("object", { id = "wc2x_escort_buff_" .. i, wml.tag.effect(buff.effect) })
					end
					break
				end
			end
		end
	end
	u.hitpoints = u.max_hitpoints
	u.moves = u.max_moves
end

function scaling.intro_line(result)
	if result.hp_pct > 0 then
		return string.format(tostring(_ "Your armies have slain %d foes on the road to this place. The slaughter has fed the enemy's master: +%d%% hitpoints."), result.kills, result.hp_pct)
	end
	return string.format(tostring(_ "Your armies have slain %d foes on the road to this place."), result.kills)
end

function scaling.readout()
	local r = scaling.measure()
	local saved = scaling.saved()
	local lines = {
		string.format("Roster value (all players, map + recall): %d gold", r.gold),
		string.format("  -> arena escort %d (13-%d), edge units %d (10-%d)", r.arena, scaling.ARENA.cap, r.edge, scaling.EDGE.cap),
		string.format("Key-unit score: %.2f (top %d per player, %d key units)", r.score, scaling.KEY_UNITS_PER_PLAYER, r.key_units),
		string.format("  -> %d shrine buffs per escort unit", r.bonuses),
		string.format("Campaign kills: %d -> boss +%d%% HP", r.kills, r.hp_pct),
		"Top key units:", r.detail,
	}
	if saved then
		table.insert(lines, string.format("Used at spawn: escort %d + %d, %d buffs, +%d%% HP", saved.arena, saved.edge, saved.bonuses, saved.hp_pct))
	end
	return table.concat(lines, "\n")
end

function scaling.init()
	-- an enemy unit killed by a player unit, anywhere in the campaign; wml.variables carry over
	wesnoth.game_events.add_repeating("die", function()
		local ec = wesnoth.current.event_context
		if not (ec.x1 and ec.x2) then return end
		local dying = wesnoth.units.get(ec.x1, ec.y1)
		local killer = wesnoth.units.get(ec.x2, ec.y2)
		if not (dying and killer) then return end
		if wesnoth.sides[killer.side].team_name ~= "wc2_player" then return end
		if wesnoth.sides[dying.side].team_name == "wc2_player" then return end
		wml.variables[KILLS_VAR] = scaling.kills() + 1
	end)
end

return scaling
