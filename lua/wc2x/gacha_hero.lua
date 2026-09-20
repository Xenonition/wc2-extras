local _ = wesnoth.textdomain 'wesnoth-wc'

local dialog_wml = wml.load "~add-ons/wc2-extras/gui/gacha_dialog.cfg"

local gacha = {}

local HERO_BASE_COST = 50
local HERO_COST_PER_SCENARIO = 12
local REROLL_ALL_COST = 15
local REROLL_BONUSES_COST = 10
local REROLL_BIGGER_COST = 35

local function weighted_pick(pool, exclude)
	local total = 0
	for i, buff in ipairs(pool) do
		if not exclude[i] then
			total = total + buff.weight
		end
	end
	if total <= 0 then return nil end
	local roll = mathx.random(total)
	local cum = 0
	for i, buff in ipairs(pool) do
		if not exclude[i] then
			cum = cum + buff.weight
			if roll <= cum then return i end
		end
	end
end

function gacha.roll_bonuses(pool, count)
	local exclude = {}
	local result = {}
	for _ = 1, count do
		local idx = weighted_pick(pool, exclude)
		if idx then
			table.insert(result, idx)
			exclude[idx] = true
		end
	end
	return result
end

local function build_slot_text(pool, buffs)
	local du = wc2x.dialog_utils
	local lines = {}
	for _, idx in ipairs(buffs) do
		table.insert(lines, "  ★ " .. du.bold(tostring(pool[idx].name)))
	end
	return du.big(table.concat(lines, "\n"))
end

local function roll_hero_type()
	local scenario_num = wc2_scenario.scenario_num()
	local min_lv, max_lv = wc2x.unit_pool.level_range_for_scenario(scenario_num)
	return wc2x.unit_pool.pick_random(min_lv, max_lv)
end

function gacha.show(side_num, discount_pct)
	local side = wesnoth.sides[side_num]
	local du = wc2x.dialog_utils
	local pool = wc2x.config.shrine_buffs

	local function disc(base)
		return math.ceil(base * (1 - (discount_pct or 0) / 100))
	end

	local scenario_num = wc2_scenario.scenario_num()
	local hero_cost = disc(HERO_BASE_COST + (scenario_num * HERO_COST_PER_SCENARIO))
	local cost_reroll_all = disc(REROLL_ALL_COST)
	local cost_reroll_bonuses = disc(REROLL_BONUSES_COST)
	local cost_reroll_bigger = disc(REROLL_BIGGER_COST)

	local gold_spent = 0
	local hero_type = roll_hero_type()
	if not hero_type then
		return { unit_type = "", buff_list = "", total_cost = 0 }
	end
	local bonus_count = mathx.random(2, 3)
	local buffs = gacha.roll_bonuses(pool, bonus_count)

	local function preshow(dialog)
		local function gold_left()
			return side.gold - gold_spent
		end

		local function update_display()
			local gl = gold_left()
			local ut = wesnoth.unit_types[hero_type]
			local img = ut and ut.image or "units/unknown-unit.png"
			dialog.hero_image.label = img .. "~SCALE(144,144)"

			local name_line = du.big(du.big(du.bold(tostring(ut and ut.name or hero_type))))
			local stats_line = string.format("Lv%d  |  HP %d  |  Moves %d  |  %s",
				ut and ut.level or 0, ut and ut.max_hitpoints or 0,
				ut and ut.max_moves or 0, tostring(ut and ut.alignment or ""))
			dialog.hero_name_label.label = name_line .. "\n" .. du.colored(stats_line, "#cccccc")

			local atk_parts = {}
			if ut then
				for _, atk in ipairs(ut.attacks) do
					table.insert(atk_parts, string.format("%s %d×%d %s (%s)",
						tostring(atk.description), atk.damage, atk.number,
						tostring(atk.type), tostring(atk.range)))
				end
			end
			dialog.hero_attacks_label.label = du.colored(table.concat(atk_parts, "   |   "), "#aaaaaa")

			dialog.bonus_slots_label.label = build_slot_text(pool, buffs)

			dialog.gold_label.label = du.gold_header(gl)
			dialog.accept_btn.label = "★ " .. tostring(_ "Accept Hero") .. " (" .. hero_cost .. "g) ★"
			dialog.accept_btn.enabled = gl >= hero_cost

			dialog.reroll_all_btn.label = "↻ " .. tostring(_ "Reroll All") .. " (" .. cost_reroll_all .. "g)"
			dialog.reroll_bonuses_btn.label = "↻ " .. tostring(_ "Reroll Bonuses") .. " (" .. cost_reroll_bonuses .. "g)"
			dialog.reroll_bigger_btn.label = "↻ " .. tostring(_ "Bigger") .. " (" .. cost_reroll_bigger .. "g, 4-5)"

			dialog.reroll_all_btn.enabled = gl >= cost_reroll_all
			dialog.reroll_bonuses_btn.enabled = gl >= cost_reroll_bonuses
			dialog.reroll_bigger_btn.enabled = gl >= cost_reroll_bigger
		end

		if discount_pct and discount_pct > 0 then
			dialog.discount_label.label = du.colored(string.format(tostring(_ "Discount: %d%%"), discount_pct), "green")
		else
			dialog.discount_label.label = ""
		end

		dialog.reroll_all_btn.on_button_click = function()
			if gold_left() < cost_reroll_all then return end
			gold_spent = gold_spent + cost_reroll_all
			hero_type = roll_hero_type()
			bonus_count = mathx.random(2, 3)
			buffs = gacha.roll_bonuses(pool, bonus_count)
			update_display()
		end

		dialog.reroll_bonuses_btn.on_button_click = function()
			if gold_left() < cost_reroll_bonuses then return end
			gold_spent = gold_spent + cost_reroll_bonuses
			bonus_count = mathx.random(2, 3)
			buffs = gacha.roll_bonuses(pool, bonus_count)
			update_display()
		end

		dialog.reroll_bigger_btn.on_button_click = function()
			if gold_left() < cost_reroll_bigger then return end
			gold_spent = gold_spent + cost_reroll_bigger
			bonus_count = mathx.random(4, 5)
			buffs = gacha.roll_bonuses(pool, bonus_count)
			update_display()
		end

		update_display()
	end

	local d_wml = wml.get_child(dialog_wml, 'resolution')
	local ret = gui.show_dialog(d_wml, preshow)

	if ret == 1 then
		local buff_strs = {}
		for _, idx in ipairs(buffs) do
			table.insert(buff_strs, tostring(idx))
		end
		return {
			unit_type = hero_type,
			buff_list = table.concat(buff_strs, ","),
			total_cost = gold_spent + hero_cost,
		}
	else
		return { unit_type = "", buff_list = "", total_cost = gold_spent }
	end
end

function gacha.place_hero(unit_type_id, side_num, x, y)
	local modifications = wc2_heroes.generate_traits(unit_type_id)
	table.insert(modifications, wml.tag.advancement { wc2_scenario.experience_penalty() })
	table.insert(modifications, wc2_heroes.hero_overlay_object())

	local u = wesnoth.units.create {
		type = unit_type_id,
		side = side_num,
		random_traits = false,
		wml.tag.modifications(modifications),
	}
	local x2, y2 = wesnoth.paths.find_vacant_hex(x, y, u)
	u:to_map(x2, y2)
	return u
end

function gacha.show_for_side(side_num)
	local side = wesnoth.sides[side_num]

	local discount_pct = 0
	if wc2x.shop and wc2x.shop.get_discount then
		discount_pct = wc2x.shop.get_discount()
	end

	local res = wesnoth.sync.evaluate_single(_ "Build a Hero", function()
		return gacha.show(side_num, discount_pct)
	end)

	local total_cost = (res and res.total_cost) or 0

	if not res or res.unit_type == "" then
		if total_cost > 0 then
			side.gold = side.gold - total_cost
		end
		return
	end

	side.gold = side.gold - total_cost

	local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
	if leader then
		local u = gacha.place_hero(res.unit_type, side_num, leader.x, leader.y)
		local buff_indices = stringx.split(res.buff_list or "")
		gacha.apply_bonuses(u, buff_indices)
	end
end

function gacha.apply_bonuses(unit, buff_index_strs)
	local pool = wc2x.config.shrine_buffs
	for _, s in ipairs(buff_index_strs) do
		local idx = tonumber(s)
		if idx and pool[idx] then
			local buff = pool[idx]
			if buff.trait then
				unit:add_modification("trait", buff.trait)
			else
				unit:add_modification("object", {
					id = "wc2x_gacha_" .. idx,
					wml.tag.effect(buff.effect),
				})
			end
		end
	end
end

return gacha
