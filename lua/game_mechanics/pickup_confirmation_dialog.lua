local _ = wesnoth.textdomain 'wesnoth-wc'

local pickup_confirmation_dialog = {}

-- Asks the moving player what to do with a WC2 item: pick it up, leave it, or send it next to
-- another player's leader. @a targets is a list of { side = n, label = "..." } built from synced
-- state, so every client maps the returned choice to the same side.
-- Returns { action = "take" | "leave" | "send", side = n }.
function pickup_confirmation_dialog.choose_synced(unit, artifact, can_take, targets)
	local res = wesnoth.sync.evaluate_single("Item Pickup Choice", function()
		-- the "skip pickup confirmation" preference is per computer, so it may only be read in here
		if can_take and wc2_utils.global_vars.skip_pickup_dialog then
			return { action = "take" }
		end
		local options, actions = {}, {}
		if can_take then
			table.insert(options, { image = artifact.icon, label = tostring(_ "Pick up") })
			table.insert(actions, { action = "take" })
		end
		table.insert(options, { label = tostring(_ "Leave it here") })
		table.insert(actions, { action = "leave" })
		for i, t in ipairs(targets) do
			table.insert(options, { label = t.label })
			table.insert(actions, { action = "send", side = t.side })
		end

		local message = tostring(artifact.info or "") .. "\n" .. wc2_color.help_text(artifact.description or "")
		if not can_take then
			message = message .. "\n\n" .. tostring(_ "This unit cannot use this item.")
		end
		local choice = gui.show_narration({
			title = artifact.name,
			message = message,
			portrait = wesnoth.unit_types[unit.type].image,
		}, options)
		return actions[choice] or { action = "leave" }
	end, function() return { action = "leave" } end)
	return res
end

return pickup_confirmation_dialog
