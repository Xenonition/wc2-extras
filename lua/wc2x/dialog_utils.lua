-- World Conquest III — shared dialog utilities

local _ = wesnoth.textdomain 'wesnoth-wc'

local du = {}

function du.gray(text) return "<span color='gray'>" .. tostring(text) .. "</span>" end
function du.colored(text, color) return "<span color='" .. color .. "'>" .. tostring(text) .. "</span>" end
function du.bold(text) return "<b>" .. tostring(text) .. "</b>" end
function du.big(text) return "<big>" .. tostring(text) .. "</big>" end
function du.strike(text) return "<span strikethrough='true'>" .. tostring(text) .. "</span>" end

function du.price_label(base_price, final_price, discount_pct)
	if discount_pct and discount_pct > 0 then
		return string.format("%s → %s gold (%s)",
			du.strike(base_price), du.bold(final_price),
			du.colored("-" .. discount_pct .. "%", "green"))
	end
	return string.format("%d gold", final_price)
end

function du.gold_header(gold)
	return string.format("<b>" .. tostring(_ "Gold: %d") .. "</b>", gold)
end

function du.populate_list(list_widget, items, format_fn)
	local rows = {}
	for i, item in ipairs(items) do
		local fmt = format_fn(item)
		local row = list_widget:add_item()
		row.item_icon.label = fmt.icon or "items/chest.png"
		row.item_name.label = fmt.name or ""
		if fmt.subtitle then
			row.item_price.label = fmt.subtitle
		end
		rows[i] = row
	end
	return rows
end

function du.wire_detail_pane(list_widget, detail_widget, items, detail_fn)
	local function update()
		local idx = list_widget.selected_index
		if idx and idx >= 1 and idx <= #items then
			detail_widget.label = detail_fn(items[idx])
		end
	end
	list_widget.on_modified = update
	if #items > 0 then
		list_widget.selected_index = 1
		update()
	end
	return update
end

function du.refresh_rows(rows, items, format_fn)
	for i, item in ipairs(items) do
		if rows[i] then
			local fmt = format_fn(item)
			rows[i].item_icon.label = fmt.icon or "items/chest.png"
			rows[i].item_name.label = fmt.name or ""
			if fmt.subtitle then
				rows[i].item_price.label = fmt.subtitle
			end
		end
	end
end

function du.build_upgrades_summary(side_num)
	local lines = {}
	table.insert(lines, du.big(du.bold(tostring(_ "Your Upgrades"))))
	table.insert(lines, "")

	local upgrades = wc2x and wc2x.upgrades
	if not upgrades then
		table.insert(lines, du.gray(tostring(_ "No upgrade data available.")))
		return table.concat(lines, "\n")
	end

	local any = false
	local defs = {
		{ id = "castle_hex", name = _ "Castle Hexes", fmt = function(n) return string.format("+%d starting castle hexes", n) end },
		{ id = "supply_village", name = _ "Supply Villages", fmt = function(n) return string.format("%d (heal + income)", n) end },
		{ id = "recall_discount", name = _ "Recall Discount", fmt = function(n) return string.format("-%d gold on recalls", n * 3) end },
		{ id = "starting_gold", name = _ "Starting Gold", fmt = function(n) return string.format("+%d gold per map", n * 15) end },
		{ id = "vision_radius", name = _ "Scout Network", fmt = function(n) return string.format("%d hex vision radius", n * 3) end },
		{ id = "reinforcements", name = _ "Reinforcements", fmt = function(n) return string.format("+%d free units at map start", n) end },
		{ id = "barracks", name = _ "Barracks", fmt = function(n) return string.format("%d (auto-spawn every %d turns)", n, wc2x.config.barracks_spawn_interval) end },
		{ id = "training_ground", name = _ "Training Grounds", fmt = function(n) return string.format("%d (+%d XP/turn each)", n, wc2x.config.training_ground_xp_per_turn) end },
	}

	for _, def in ipairs(defs) do
		local count = upgrades.get_count(side_num, def.id)
		if count > 0 then
			any = true
			table.insert(lines, string.format("  %s  %s", du.bold(tostring(def.name) .. ":"), def.fmt(count)))
		end
	end

	local side = wesnoth.sides[side_num]
	local recruit_list = side.recruit
	local discounts = {}
	for _, rtype in ipairs(recruit_list) do
		local d = side.variables["wc2x_unit_discount." .. rtype] or 0
		if d > 0 then
			local utype = wesnoth.unit_types[rtype]
			local name = utype and tostring(utype.name) or rtype
			table.insert(discounts, string.format("  %s: %s", name, du.colored(string.format("-%dg", d), "green")))
		end
	end
	if #discounts > 0 then
		any = true
		table.insert(lines, "")
		table.insert(lines, du.bold(tostring(_ "Unit Discounts:")))
		for _, d in ipairs(discounts) do table.insert(lines, d) end
	end

	if not any then
		table.insert(lines, du.gray(tostring(_ "No upgrades purchased yet.")))
		table.insert(lines, "")
		table.insert(lines, tostring(_ "Browse the items on the left and click Buy to spend your gold on permanent upgrades or artifacts."))
	end

	return table.concat(lines, "\n")
end

function du.build_invest_summary(side_num)
	local lines = {}
	table.insert(lines, du.big(du.bold(tostring(_ "Current Status"))))
	table.insert(lines, "")

	local has_content = false

	if wc2_training then
		local training_lines = {}
		local trainers = wc2_training.get_list() or {}
		for i, trainer in ipairs(trainers) do
			local level = wc2_training.get_level(side_num, i)
			if level > 0 then
				local max_level = trainer.grade and #trainer.grade or "?"
				table.insert(training_lines, string.format("  %s: Level %d/%s", du.bold(tostring(trainer.name)), level, tostring(max_level)))
			end
		end
		if #training_lines > 0 then
			has_content = true
			table.insert(lines, du.bold(tostring(_ "Training:")))
			for _, l in ipairs(training_lines) do table.insert(lines, l) end
			table.insert(lines, "")
		end
	end

	if wc2x and wc2x.upgrades then
		local upgrade_lines = {}
		local upgrade_defs = {
			{ id = "castle_hex", name = _ "Castle Hexes" },
			{ id = "supply_village", name = _ "Supply Villages" },
			{ id = "recall_discount", name = _ "Recall Discount" },
			{ id = "starting_gold", name = _ "Starting Gold" },
			{ id = "vision_radius", name = _ "Scout Network" },
			{ id = "reinforcements", name = _ "Reinforcements" },
			{ id = "barracks", name = _ "Barracks" },
			{ id = "training_ground", name = _ "Training Grounds" },
		}
		for _, def in ipairs(upgrade_defs) do
			local count = wc2x.upgrades.get_count(side_num, def.id)
			if count > 0 then
				table.insert(upgrade_lines, string.format("  %s: %d", du.bold(tostring(def.name)), count))
			end
		end
		if #upgrade_lines > 0 then
			has_content = true
			table.insert(lines, du.bold(tostring(_ "Shop Upgrades:")))
			for _, l in ipairs(upgrade_lines) do table.insert(lines, l) end
			table.insert(lines, "")
		end
	end

	if not has_content then
		table.insert(lines, tostring(_ "No bonuses acquired yet. Choose your first reward!"))
	end

	return table.concat(lines, "\n")
end

function du.unit_detail_text(utype, gold, cost)
	local lines = {}
	table.insert(lines, du.big(du.bold(tostring(utype.name))))
	table.insert(lines, "")
	local race_name = utype.race
	if wesnoth.races and wesnoth.races[utype.race] then
		race_name = wesnoth.races[utype.race].name
	end
	table.insert(lines, string.format("%s — Level %d", race_name, utype.level))
	table.insert(lines, string.format("HP: %d  |  MP: %d  |  %s", utype.max_hitpoints, utype.max_moves, utype.alignment))
	table.insert(lines, "")

	table.insert(lines, du.bold(tostring(_ "Attacks:")))
	for _, atk in ipairs(utype.attacks) do
		table.insert(lines, string.format("  %s — %d×%d %s (%s)", tostring(atk.description), atk.damage, atk.number, atk.type, atk.range))
	end

	table.insert(lines, "")
	if gold >= cost then
		table.insert(lines, du.colored(string.format(tostring(_ "Cost: %d gold"), cost), "yellow"))
	else
		table.insert(lines, du.colored(string.format(tostring(_ "Cost: %d gold — not enough!"), cost), "#cc3333"))
	end

	return table.concat(lines, "\n")
end

return du
