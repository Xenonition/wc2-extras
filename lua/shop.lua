-- WC2 Extras — between-map shop
-- Shows after victory, before proceeding to next scenario.
-- Players spend leftover gold on consumables (random subset) and permanent upgrades.

local on_event = wesnoth.game_events.add_repeating
local _ = wesnoth.textdomain 'wesnoth-wc2-extras'
local config = wc2x.config

local shop = {}

-- Calculate early-finish discount percentage
function shop.get_discount()
	local turns_left = math.max(wesnoth.scenario.turns - wesnoth.current.turn, 0)
	local discount = turns_left * config.shop_discount_per_turn_early
	return math.min(discount, config.shop_max_discount)
end

-- Apply discount to a price
function shop.discounted_price(base_price)
	local discount = shop.get_discount()
	return math.ceil(base_price * (1 - discount / 100))
end

-- Build the list of available consumables (random subset from WC2's pool)
function shop.build_consumable_list()
	local consumables = {}

	-- Artifacts from WC2
	if wc2_artifacts then
		local all_artifacts = wc2_artifacts.get_artifact_list()
		local indices = {}
		for i = 1, #all_artifacts do
			table.insert(indices, i)
		end
		mathx.shuffle(indices)
		for i = 1, math.min(config.shop_consumable_slots, #indices) do
			local artifact = all_artifacts[indices[i]]
			table.insert(consumables, {
				category = "artifact",
				id = indices[i],
				name = artifact.name,
				description = artifact.description or "",
				icon = artifact.icon or "items/chest.png",
				price = 30 + (wc2_scenario.scenario_num() * 10),
			})
		end
	end

	return consumables
end

-- Build the permanent upgrades list with current prices
function shop.build_upgrade_list(side_num)
	local upgrades_mod = wc2x.upgrades
	local items = {}

	local defs = {
		{ id = "castle_hex", name = _ "Castle Hex", desc = _ "+1 starting castle hex" },
		{ id = "supply_village", name = _ "Supply Village", desc = _ "Castle hex with village (heals + income)" },
		{ id = "unit_discount", name = _ "Unit Discount", desc = _ "Reduce recruit cost of a unit type" },
		{ id = "recall_discount", name = _ "Recall Discount", desc = _ "-3 gold on all recalls" },
		{ id = "starting_gold", name = _ "Starting Gold", desc = _ "+15 base gold each map" },
		{ id = "vision_radius", name = _ "Scout Network", desc = _ "+3 hex vision at start" },
		{ id = "reinforcements", name = _ "Reinforcements", desc = _ "+1 free unit at map start" },
		{ id = "barracks", name = _ "Barracks", desc = string.format(_ "Auto-spawns a recruit every %d turns", config.barracks_spawn_interval) },
		{ id = "training_ground", name = _ "Training Ground", desc = string.format(_ "Castle hex: units gain +%d XP per turn", config.training_ground_xp_per_turn) },
	}

	for _, def in ipairs(defs) do
		local count = upgrades_mod.get_count(side_num, def.id)
		local price = upgrades_mod.get_price(side_num, def.id)
		table.insert(items, {
			category = "upgrade",
			id = def.id,
			name = def.name,
			description = def.desc,
			price = price,
			owned = count,
		})
	end

	return items
end

-- Show the shop dialog for a side
-- TODO: this is a placeholder that uses message-based UI.
-- Replace with a proper GUI dialog (like WC2's invest screen) once the
-- mechanic is validated through playtesting.
function shop.show_for_side(side_num)
	local side = wesnoth.sides[side_num]
	local discount = shop.get_discount()
	local upgrades_mod = wc2x.upgrades

	wesnoth.wml_actions.message {
		speaker = "narrator",
		caption = _ "Between-Battle Shop",
		message = string.format(
			_ "Victory! You have %d gold to spend.\nEarly finish discount: %d%%",
			side.gold, discount
		),
		image = "scenery/tent-shop-weapons.png",
	}

	-- Simple iterative shop: keep offering purchases until player is done
	local shopping = true
	while shopping do
		local options = {}
		local option_data = {}

		-- Add consumables
		local consumables = shop.build_consumable_list()
		for _, item in ipairs(consumables) do
			local price = shop.discounted_price(item.price)
			if side.gold >= price then
				table.insert(options, wml.tag.option {
					label = string.format("%s (%dg)", item.name, price),
					description = item.description,
				})
				table.insert(option_data, { type = "consumable", data = item, price = price })
			end
		end

		-- Add permanent upgrades
		local upgrade_list = shop.build_upgrade_list(side_num)
		for _, item in ipairs(upgrade_list) do
			local price = shop.discounted_price(item.price)
			if side.gold >= price then
				local owned_str = item.owned > 0
					and string.format(" [owned: %d]", item.owned)
					or ""
				table.insert(options, wml.tag.option {
					label = string.format("%s (%dg)%s", item.name, price, owned_str),
					description = item.description,
				})
				table.insert(option_data, { type = "upgrade", data = item, price = price })
			end
		end

		-- Add "done" option
		table.insert(options, wml.tag.option { label = _ "Done Shopping" })
		table.insert(option_data, { type = "done" })

		-- Show the menu
		local menu_cfg = {
			speaker = "narrator",
			caption = string.format(_ "Shop — %d gold remaining", side.gold),
			message = _ "Choose an item to purchase:",
			image = "scenery/tent-shop-weapons.png",
		}
		for _, opt in ipairs(options) do
			table.insert(menu_cfg, opt)
		end
		wesnoth.wml_actions.message(menu_cfg)

		local choice = wml.variables.value
		if not choice or choice >= #option_data - 1 then
			-- "Done" selected or last option
			shopping = false
		else
			local selected = option_data[choice + 1]
			if selected.type == "consumable" then
				side.gold = side.gold - selected.price
				-- Give the artifact to the side's leader (or first unit)
				local leader = wesnoth.units.find_on_map({ side = side_num, canrecruit = true })[1]
				if leader and wc2_artifacts then
					wc2_artifacts.give_item(leader, selected.data.id, true)
				end
			elseif selected.type == "upgrade" then
				side.gold = side.gold - selected.price
				upgrades_mod.purchase(side_num, selected.data.id)

				-- Special handling for unit discount: ask which type
				if selected.data.id == "unit_discount" then
					local recruit_list = stringx.split(side.recruit)
					if #recruit_list > 0 then
						local type_options = {}
						for _, rtype in ipairs(recruit_list) do
							table.insert(type_options, wml.tag.option {
								label = wesnoth.unit_types[rtype].name,
							})
						end
						wesnoth.wml_actions.message {
							speaker = "narrator",
							caption = _ "Unit Discount",
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
					speaker = "narrator",
					caption = _ "Purchased!",
					message = string.format(_ "%s acquired. It will take effect next map.", selected.data.name),
					image = "scenery/tent-shop-weapons.png",
				}
			end
		end
	end
end

-- Hook into victory event to show shop before transitioning
-- Priority lower than WC2's own victory handler so carryover is set first
on_event("victory", function(cx)
	-- Don't show shop on final scenario
	if (wml.variables.wc2_scenario or 1) > 5 then return end

	for side_num = 1, (wml.variables.wc2_player_count or 1) do
		local side = wesnoth.sides[side_num]
		if side.is_local then
			shop.show_for_side(side_num)
		end
	end
end)

return shop
