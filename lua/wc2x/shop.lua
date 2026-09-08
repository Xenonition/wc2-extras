-- WC2 Extras — between-map shop

local on_event = wesnoth.game_events.add_repeating
local _ = wesnoth.textdomain 'wesnoth-wc'

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

function shop.build_consumable_list()
	local consumables = {}
	if wc2_artifacts then
		local all_artifacts = wc2_artifacts.get_artifact_list()
		local indices = {}
		for i = 1, #all_artifacts do table.insert(indices, i) end
		mathx.shuffle(indices)
		for i = 1, math.min(shop.config.shop_consumable_slots, #indices) do
			local artifact = all_artifacts[indices[i]]
			table.insert(consumables, {
				category = "artifact", id = indices[i],
				name = artifact.name, description = artifact.description or "",
				icon = artifact.icon or "items/chest.png",
				price = 30 + (wc2_scenario.scenario_num() * 10),
			})
		end
	end
	return consumables
end

function shop.build_upgrade_list(side_num)
	local config = shop.config
	local items = {}
	local defs = {
		{ id = "castle_hex", name = _ "Castle Hex", desc = _ "+1 starting castle hex" },
		{ id = "supply_village", name = _ "Supply Village", desc = _ "Castle hex with village (heals + income)" },
		{ id = "unit_discount", name = _ "Unit Discount", desc = _ "Reduce recruit cost of a unit type" },
		{ id = "recall_discount", name = _ "Recall Discount", desc = _ "-3 gold on all recalls" },
		{ id = "starting_gold", name = _ "Starting Gold", desc = _ "+15 base gold each map" },
		{ id = "vision_radius", name = _ "Scout Network", desc = _ "+3 hex vision at start" },
		{ id = "reinforcements", name = _ "Reinforcements", desc = _ "+1 free unit at map start" },
		{ id = "barracks", name = _ "Barracks", desc = string.format(tostring(_ "Auto-spawns a recruit every %d turns"), config.barracks_spawn_interval) },
		{ id = "training_ground", name = _ "Training Ground", desc = string.format(tostring(_ "Castle hex: units gain +%d XP per turn"), config.training_ground_xp_per_turn) },
	}
	for _, def in ipairs(defs) do
		table.insert(items, {
			category = "upgrade", id = def.id,
			name = def.name, description = def.desc,
			price = shop.upgrades.get_price(side_num, def.id),
			owned = shop.upgrades.get_count(side_num, def.id),
		})
	end
	return items
end

function shop.show_for_side(side_num)
	local side = wesnoth.sides[side_num]
	local discount = shop.get_discount()

	wesnoth.wml_actions.message {
		speaker = "narrator", caption = _ "Between-Battle Shop",
		message = string.format(tostring(_ "Victory! You have %d gold to spend.\nEarly finish discount: %d%%"), side.gold, discount),
		image = "scenery/tent-shop-weapons.png",
	}

	local shopping = true
	while shopping do
		local options = {}
		local option_data = {}

		for _, item in ipairs(shop.build_consumable_list()) do
			local price = shop.discounted_price(item.price)
			if side.gold >= price then
				table.insert(options, wml.tag.option { label = string.format("%s (%dg)", tostring(item.name), price), description = tostring(item.description) })
				table.insert(option_data, { type = "consumable", data = item, price = price })
			end
		end

		for _, item in ipairs(shop.build_upgrade_list(side_num)) do
			local price = shop.discounted_price(item.price)
			if side.gold >= price then
				local owned_str = item.owned > 0 and string.format(" [x%d]", item.owned) or ""
				table.insert(options, wml.tag.option { label = string.format("%s (%dg)%s", tostring(item.name), price, owned_str), description = tostring(item.description) })
				table.insert(option_data, { type = "upgrade", data = item, price = price })
			end
		end

		table.insert(options, wml.tag.option { label = _ "Done Shopping" })
		table.insert(option_data, { type = "done" })

		local menu_cfg = {
			speaker = "narrator",
			caption = string.format(tostring(_ "Shop — %d gold remaining"), side.gold),
			message = _ "Choose an item to purchase:",
			image = "scenery/tent-shop-weapons.png",
		}
		for _, opt in ipairs(options) do table.insert(menu_cfg, opt) end
		wesnoth.wml_actions.message(menu_cfg)

		local choice = wml.variables.value
		if not choice or choice >= #option_data - 1 then
			shopping = false
		else
			local selected = option_data[choice + 1]
			if selected.type == "consumable" then
				side.gold = side.gold - selected.price
				local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
				if leader and wc2_artifacts then
					wc2_artifacts.give_item(leader, selected.data.id, true)
				end
			elseif selected.type == "upgrade" then
				side.gold = side.gold - selected.price
				shop.upgrades.purchase(side_num, selected.data.id)

				if selected.data.id == "unit_discount" then
					local recruit_list = stringx.split(side.recruit)
					if #recruit_list > 0 then
						local type_options = {}
						for _, rtype in ipairs(recruit_list) do
							table.insert(type_options, wml.tag.option { label = wesnoth.unit_types[rtype].name })
						end
						wesnoth.wml_actions.message {
							speaker = "narrator", caption = _ "Unit Discount",
							message = _ "Choose a unit type to discount:",
							unpack(type_options),
						}
						local type_choice = wml.variables.value or 0
						if type_choice < #recruit_list then
							local chosen_type = recruit_list[type_choice + 1]
							local key = "wc2x_unit_discount." .. chosen_type
							side.variables[key] = (side.variables[key] or 0) + 5
						end
					end
				end

				wesnoth.wml_actions.message {
					speaker = "narrator", caption = _ "Purchased!",
					message = string.format(tostring(_ "%s acquired. It will take effect next map."), tostring(selected.data.name)),
					image = "scenery/tent-shop-weapons.png",
				}
			end
		end
	end
end

return shop
