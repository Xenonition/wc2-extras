-- World Conquest III — between-map shop

local on_event = wesnoth.game_events.add_repeating
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
				info = artifact.info or "",
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
		{ id = "castle_hex", name = _ "Castle Hex", desc = _ "+1 starting castle hex", icon = "terrain/castle/encampment/castle-n.png",
		  detail = _ "Adds one extra castle hex adjacent to your keep at the start of each map. More castle = faster recruiting." },
		{ id = "supply_village", name = _ "Supply Village", desc = _ "Castle hex with village (heals + income)", icon = "terrain/village/human-city-ruin.png",
		  detail = _ "Places a village on a new castle hex next to your keep. Provides healing, income, and an extra recruit slot." },
		{ id = "unit_discount", name = _ "Unit Discount", desc = _ "Reduce recruit cost of a unit type", icon = "icons/coins_copper.png",
		  detail = _ "Choose one unit type from your recruit list. Its cost is permanently reduced by 5 gold. Stacks." },
		{ id = "recall_discount", name = _ "Recall Discount", desc = _ "-3 gold on all recalls", icon = "icons/coins_silver.png",
		  detail = _ "Reduces the recall cost for all your units by 3 gold. Stacks with multiple purchases." },
		{ id = "starting_gold", name = _ "Starting Gold", desc = _ "+15 base gold each map", icon = "icons/coins_gold.png",
		  detail = _ "You start each future map with 15 extra gold. Stacks." },
		{ id = "vision_radius", name = _ "Scout Network", desc = _ "+3 hex vision at start", icon = "icons/vision.png",
		  detail = _ "Lifts fog of war in a 3-hex radius around your leader at the start of each map. Stacks." },
		{ id = "reinforcements", name = _ "Reinforcements", desc = _ "+1 free unit at map start", icon = "icons/unit.png",
		  detail = _ "A random unit from your recruit list spawns next to your leader for free at the start of each map. Stacks." },
		{ id = "barracks", name = _ "Barracks", desc = string.format(tostring(_ "Auto-spawns a recruit every %d turns"), config.barracks_spawn_interval), icon = "terrain/castle/encampment/castle-n.png",
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
	local lines = {}

	table.insert(lines, "<big><b>" .. tostring(item.name) .. "</b></big>")
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
	if discount > 0 then
		local base = item.price
		table.insert(lines, string.format("<b>" .. tostring(_ "Price:") .. "</b> <span strikethrough='true'>%d</span> → <b>%d</b> gold (<span color='green'>-%d%%</span>)", base, price, discount))
	else
		table.insert(lines, string.format("<b>" .. tostring(_ "Price:") .. "</b> %d gold", price))
	end

	if item.owned and item.owned > 0 then
		table.insert(lines, string.format("<b>" .. tostring(_ "Owned:") .. "</b> %d", item.owned))
	end

	if not can_afford then
		table.insert(lines, "")
		table.insert(lines, "<span color='#cc3333'>" .. tostring(_ "Not enough gold!") .. "</span>")
	end

	return table.concat(lines, "\n")
end

function shop.show_for_side(side_num)
	local side = wesnoth.sides[side_num]
	local discount = shop.get_discount()

	local shopping = true
	while shopping do
		local all_items = {}
		for _, item in ipairs(shop.build_consumable_list()) do
			table.insert(all_items, item)
		end
		for _, item in ipairs(shop.build_upgrade_list(side_num)) do
			table.insert(all_items, item)
		end

		if #all_items == 0 then
			shopping = false
			break
		end

		local selected_idx = 1

		local function preshow(dialog)
			dialog.gold_label.label = string.format("<b>" .. tostring(_ "Gold: %d") .. "</b>", side.gold)
			if discount > 0 then
				dialog.discount_label.label = string.format("<span color='green'>" .. tostring(_ "Discount: %d%%") .. "</span>", discount)
			else
				dialog.discount_label.label = ""
			end

			local list = dialog.shop_list
			for _, item in ipairs(all_items) do
				local price = shop.discounted_price(item.price)
				local can_afford = side.gold >= price

				local row = list:add_item()
				local name_str = tostring(item.name)
				if item.owned and item.owned > 0 then
					name_str = name_str .. string.format(" <span color='#aaaaff'>[x%d]</span>", item.owned)
				end
				if not can_afford then
					name_str = "<span color='gray'>" .. name_str .. "</span>"
				end

				row.item_icon.label = item.icon or "items/chest.png"
				row.item_name.label = name_str
				local price_str
				if can_afford then
					price_str = string.format("<span color='yellow'>%d gold</span>", price)
				else
					price_str = string.format("<span color='gray'>%d gold</span>", price)
				end
				row.item_price.label = price_str
			end

			local function update_detail()
				local idx = list.selected_index
				if idx and idx >= 1 and idx <= #all_items then
					selected_idx = idx
					local item = all_items[idx]
					local price = shop.discounted_price(item.price)
					local can_afford = side.gold >= price
					dialog.detail_text.label = shop.build_detail_text(item, price, can_afford, discount)
				end
			end

			list.on_modified = update_detail

			if #all_items > 0 then
				list.selected_index = 1
				update_detail()
			end
		end

		local d_wml = wml.get_child(dialog_wml, 'resolution')
		local d_res = gui.show_dialog(d_wml, preshow)

		-- ok button (Buy) returns -1, cancel button (Done) returns -2
		if d_res == -2 then
			shopping = false
		elseif d_res == -1 and selected_idx >= 1 and selected_idx <= #all_items then
			local item = all_items[selected_idx]
			local price = shop.discounted_price(item.price)
			if side.gold >= price then
				if item.category == "artifact" then
					side.gold = side.gold - price
					local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
					if leader and wc2_artifacts then
						wc2_artifacts.give_item(leader, item.id, true)
					end
				elseif item.category == "upgrade" then
					side.gold = side.gold - price
					shop.upgrades.purchase(side_num, item.id)

					if item.id == "unit_discount" then
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
				end
			end
		end
	end
end

return shop
