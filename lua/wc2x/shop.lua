-- World Conquest III — between-map shop

local _ = wesnoth.textdomain 'wesnoth-wc'

local dialog_wml = wml.load "~add-ons/wc2-extras/gui/shop_dialog.cfg"

local shop = {}

function shop.init(config, upgrades_mod)
	shop.config = config
	shop.upgrades = upgrades_mod
end

function shop.get_discount()
	local turns_left = math.max(wesnoth.scenario.turns - wesnoth.current.turn, 0)
	return math.min(turns_left * shop.config.shop_discount_per_turn_early, shop.config.shop_max_discount)
end

function shop.discounted_price(base_price)
	return math.ceil(base_price * (1 - shop.get_discount() / 100))
end

function shop.build_consumable_list(side_num)
	local consumables = {}
	local slots = shop.config.shop_slots_per_category
	local scenario_num = wc2_scenario.scenario_num()

	if wc2_artifacts then
		local all_artifacts = wc2_artifacts.get_artifact_list()
		local indices = {}
		for i = 1, #all_artifacts do table.insert(indices, i) end
		mathx.shuffle(indices)
		local offset = ((side_num - 1) * slots) % #indices
		for i = 1, math.min(slots, #indices) do
			local idx = ((offset + i - 1) % #indices) + 1
			local artifact = all_artifacts[indices[idx]]
			table.insert(consumables, {
				category = "artifact", id = indices[idx],
				name = artifact.name, description = artifact.description or "",
				icon = artifact.icon or "items/chest.png",
				info = artifact.info or "",
				price = 30 + (scenario_num * 10),
			})
		end
	end

	if wc2_training then
		local available = wc2_training.list_available(side_num)
		mathx.shuffle(available)
		for i = 1, math.min(slots, #available) do
			local trainer_idx = available[i]
			local trainer = wc2_training.get_trainer(trainer_idx)
			local cur_level = wc2_training.get_level(side_num, trainer_idx)
			local max_level = #trainer.grade - 1
			local desc = wc2_training.describe_training_level(trainer.name, cur_level, max_level)
				.. " → " .. wc2_training.describe_training_level(trainer.name, cur_level + 1, max_level)
			table.insert(consumables, {
				category = "training", id = trainer_idx,
				name = tostring(trainer.name) .. " " .. tostring(_ "Training"),
				description = desc,
				icon = trainer.image or "units/unknown-unit.png",
				price = 40 + (scenario_num * 8),
			})
		end
	end

	local heroes_str = wesnoth.sides[side_num].variables["wc2.heroes"] or ""
	if heroes_str ~= "" then
		local hero_ids = stringx.split(heroes_str)
		mathx.shuffle(hero_ids)
		for i = 1, math.min(slots, #hero_ids) do
			local hero_id = hero_ids[i]
			local utype = wesnoth.unit_types[hero_id]
			if utype then
				table.insert(consumables, {
					category = "hero", id = hero_id,
					name = utype.name, description = _ "Recruit a hero unit",
					icon = utype.image or "units/unknown-unit.png",
					price = 50 + (scenario_num * 12),
				})
			end
		end
	end

	return consumables
end

function shop.build_upgrade_list(side_num)
	local config = shop.config
	local items = {}
	local defs = {
		{ id = "castle_hex", name = _ "Castle Hex", desc = _ "+1 starting castle hex", icon = "scenery/castle-ruins.png",
		  detail = _ "Adds one extra castle hex adjacent to your keep at the start of each map. More castle = faster recruiting." },
		{ id = "supply_village", name = _ "Supply Village", desc = _ "Castle hex with village (heals + income)", icon = "scenery/wct-outpost.png",
		  detail = _ "Places a village on a new castle hex next to your keep. Provides healing, income, and an extra recruit slot." },
		{ id = "base_income", name = _ "Trade Route", desc = _ "+3 base income per turn", icon = "items/gold-coins-small.png",
		  detail = _ "Increases your base income by 3 gold per turn. Stacks." },
		{ id = "vision_radius", name = _ "Scout Network", desc = _ "+3 hex vision at start", icon = "misc/vision-fog.png",
		  detail = _ "Lifts fog of war in a 3-hex radius around your leader at the start of each map. Stacks." },
		{ id = "reinforcements", name = _ "Reinforcements", desc = _ "+1 free unit at map start", icon = "icons/crossed_sword_and_hammer.png",
		  detail = _ "A random unit from your recruit list spawns next to your leader for free at the start of each map. Stacks." },
		{ id = "barracks", name = _ "Barracks", desc = string.format(tostring(_ "Auto-spawns a recruit every %d turns"), config.barracks_spawn_interval), icon = "scenery/castle-ruins.png",
		  detail = string.format(tostring(_ "Places a special castle hex that automatically spawns a random recruit every %d turns. The hex must be empty for the spawn to occur."), config.barracks_spawn_interval) },
		{ id = "training_ground", name = _ "Training Ground", desc = string.format(tostring(_ "Castle hex: units gain +%d XP per turn"), config.training_ground_xp_per_turn), icon = "icons/potion_red_small.png",
		  detail = string.format(tostring(_ "Places a special castle hex. Any non-leader unit ending their turn on it gains %d XP. Units that reach max XP will advance automatically."), config.training_ground_xp_per_turn) },
	}
	for _, def in ipairs(defs) do
		table.insert(items, {
			category = "upgrade", id = def.id,
			name = def.name, description = def.desc,
			icon = def.icon,
			detail = def.detail,
			price = shop.upgrades.get_price(side_num, def.id),
			owned = shop.upgrades.get_count(side_num, def.id),
		})
	end
	return items
end

function shop.build_detail_text(item, price, can_afford, discount)
	local du = wc2x.dialog_utils
	local lines = {}

	table.insert(lines, du.big(du.bold(tostring(item.name))))
	table.insert(lines, "")
	table.insert(lines, tostring(item.description))

	if item.detail then
		table.insert(lines, "")
		table.insert(lines, tostring(item.detail))
	elseif item.info and item.info ~= "" then
		table.insert(lines, "")
		table.insert(lines, tostring(item.info))
	end

	table.insert(lines, "")
	table.insert(lines, du.bold(tostring(_ "Price:")) .. " " .. du.price_label(item.price, price, discount))

	if item.owned and item.owned > 0 then
		table.insert(lines, string.format("%s %d", du.bold(tostring(_ "Owned:")), item.owned))
	end

	if not can_afford then
		table.insert(lines, "")
		table.insert(lines, du.colored(tostring(_ "Not enough gold!"), "#cc3333"))
	end

	return table.concat(lines, "\n")
end

function shop.show_for_side(side_num)
	local side = wesnoth.sides[side_num]
	local discount = shop.get_discount()
	local du = wc2x.dialog_utils

	local consumables = shop.build_consumable_list(side_num)
	local all_items = {}
	for _, item in ipairs(consumables) do table.insert(all_items, item) end
	for _, item in ipairs(shop.build_upgrade_list(side_num)) do table.insert(all_items, item) end

	if #all_items == 0 then return end

	local res = wesnoth.sync.evaluate_single(_ "WC3 Shop", function()
		local gold_remaining = side.gold
		local purchase_strings = {}

		local function format_item(item)
			local price = shop.discounted_price(item.price)
			local can_afford = gold_remaining >= price
			local name_str = tostring(item.name)
			if item.sold then
				return { icon = item.icon, name = du.gray(name_str .. " — SOLD"), subtitle = "" }
			end
			if item.owned and item.owned > 0 then
				name_str = name_str .. du.colored(string.format(" [x%d]", item.owned), "#aaaaff")
			end
			if not can_afford then name_str = du.gray(name_str) end
			local price_str = can_afford
				and du.colored(string.format("%d gold", price), "yellow")
				or du.gray(string.format("%d gold", price))
			return { icon = item.icon or "items/chest.png", name = name_str, subtitle = price_str }
		end

		local function preshow(dialog)
			dialog.gold_label.label = du.gold_header(gold_remaining)
			if discount > 0 then
				dialog.discount_label.label = du.colored(string.format(tostring(_ "Discount: %d%%"), discount), "green")
			else
				dialog.discount_label.label = ""
			end

			dialog.detail_text.label = du.build_upgrades_summary(side_num)

			local list = dialog.shop_list
			local rows = du.populate_list(list, all_items, format_item)

			local function update_detail()
				local idx = list.selected_index
				if idx and idx >= 1 and idx <= #all_items then
					local item = all_items[idx]
					if item.sold then
						dialog.detail_text.label = du.gray(tostring(_ "Already purchased."))
					else
						local price = shop.discounted_price(item.price)
						dialog.detail_text.label = shop.build_detail_text(item, price, gold_remaining >= price, discount)
					end
				end
			end
			list.on_modified = update_detail

			dialog.buy_btn.on_button_click = function()
				local idx = list.selected_index
				if not idx or idx < 1 or idx > #all_items then return end
				local item = all_items[idx]
				if item.sold then return end
				local price = shop.discounted_price(item.price)
				if gold_remaining < price then return end

				gold_remaining = gold_remaining - price
				table.insert(purchase_strings, item.category .. ":" .. tostring(item.id) .. ":" .. price)

				if item.category == "upgrade" then
					item.owned = (item.owned or 0) + 1
					item.price = math.ceil(item.price * shop.config.upgrade_price_escalation)
				else
					item.sold = true
				end

				dialog.gold_label.label = du.gold_header(gold_remaining)
				du.refresh_rows(rows, all_items, format_item)
				update_detail()
			end
		end

		local d_wml = wml.get_child(dialog_wml, 'resolution')
		if not d_wml then return { purchases = "" } end
		gui.show_dialog(d_wml, preshow)

		return { purchases = table.concat(purchase_strings, ";") }
	end, side_num)

	local purchases_str = res.purchases or ""
	if purchases_str == "" then return end
	for entry in purchases_str:gmatch("[^;]+") do
		local category, id_str, price_str = entry:match("^(.-):(.-):(.+)$")
		local price = tonumber(price_str)
		local id = tonumber(id_str) or id_str

		side.gold = side.gold - price

		if category == "artifact" then
			local existing = side.variables["wc2x_pending_artifacts"] or ""
			local pending = existing ~= "" and stringx.split(existing) or {}
			table.insert(pending, tostring(id))
			side.variables["wc2x_pending_artifacts"] = table.concat(pending, ",")
		elseif category == "training" then
			if wc2_training and wc2_training.available(side_num, id) then
				wc2_training.inc_level(side_num, id, 1)
				local msg = wc2_training.generate_message(id, wc2_training.get_level(side_num, id))
				wesnoth.wml_actions.message(msg)
			end
		elseif category == "hero" then
			local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
			if leader then
				wc2_heroes.place(id, side_num, leader.x, leader.y)
			end
		elseif category == "upgrade" then
			shop.upgrades.purchase(side_num, id)
		end
	end
end

return shop
