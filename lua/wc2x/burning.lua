-- "burning" weapon special: modelled on Wesnoth's core stun.lua. A hit sets the target alight for
-- BURN_TURNS of its own turns (orange tint + status icon); each turn it takes BURN_DAMAGE fire damage
-- after healing, which can't kill. Re-hitting resets the timer instead of stacking. State is a unit
-- variable, so it survives save/load.

local _ = wesnoth.textdomain 'wesnoth-wc'

local burning = {}

local SPECIAL_ID = "wc3_burning"
local OBJECT_ID = "wc3_burning"
local BURN_DAMAGE = 6
local BURN_TURNS = 2
local ICON = "misc/wc3-burning-status-icon.png"

local old_unit_status = wesnoth.interface.game_display.unit_status
function wesnoth.interface.game_display.unit_status()
	local s = old_unit_status()
	local u = wesnoth.interface.get_displayed_unit()
	if u and (u.variables.wc3_burning_turns or 0) > 0 then
		table.insert(s, wml.tag.element {
			image = ICON,
			tooltip = string.format(tostring(_ "burning: This unit takes %d fire damage at the start of its turn for %d more turn(s). Burning cannot kill."),
				BURN_DAMAGE, u.variables.wc3_burning_turns),
		})
	end
	return s
end

local function ignite(u)
	if not u or u.hitpoints <= 0 then return end
	local already = (u.variables.wc3_burning_turns or 0) > 0
	u.variables.wc3_burning_turns = BURN_TURNS
	if not already then
		u:add_modification("object", {
			id = OBJECT_ID,
			wml.tag.effect { apply_to = "image_mod", add = "BLEND(255,110,0,0.35)" },
		})
	end
	if not wesnoth.interface.is_skipping_messages() then
		wesnoth.interface.float_label(u.x, u.y, tostring(_ "burning"), "255,140,0")
	end
end

local function extinguish(u)
	u:remove_modifications({ id = OBJECT_ID }, "object")
	u.variables.wc3_burning_turns = nil
end

function burning.init()
	wesnoth.game_events.add {
		name = "attacker_hits",
		first_time_only = false,
		filter = { attack = { special_id_active = SPECIAL_ID } },
		action = function()
			local ctx = wesnoth.current.event_context
			ignite(wesnoth.units.get(ctx.x2, ctx.y2))
		end,
	}
	wesnoth.game_events.add {
		name = "defender_hits",
		first_time_only = false,
		filter = { second_attack = { special_id_active = SPECIAL_ID } },
		action = function()
			local ctx = wesnoth.current.event_context
			ignite(wesnoth.units.get(ctx.x1, ctx.y1))
		end,
	}

	-- "turn refresh" runs after start-of-turn healing, so villages and healers don't cancel the burn
	wesnoth.game_events.add_repeating("turn refresh", function()
		local side = wesnoth.current.side
		for i, u in ipairs(wesnoth.units.find_on_map { side = side }) do
			local turns = u.variables.wc3_burning_turns or 0
			if turns > 0 then
				wesnoth.wml_actions.harm_unit {
					wml.tag.filter { id = u.id },
					amount = BURN_DAMAGE,
					damage_type = "fire",
					kill = false,
					fire_event = false,
					experience = false,
					animate = false,
				}
				u = wesnoth.units.find_on_map({ id = u.id })[1]
				if u then
					if turns <= 1 then extinguish(u) else u.variables.wc3_burning_turns = turns - 1 end
				end
			end
		end
	end)
end

return burning
