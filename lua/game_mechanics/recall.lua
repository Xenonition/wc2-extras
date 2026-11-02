local function add_rc_object(u)
	if not u.variables.wc2_has_recall_object then
		u.variables.wc2_has_recall_object = true
		u:add_modification("object", {
			{"effect", {
				apply_to = "wc2_recall_cost"
			}},
		})
	else
		-- WC3: re-run the effect so a Quartermaster bought since then applies to existing units
		wesnoth.effects.wc2_recall_cost(u, {})
	end
end

-- the implementation of the addons reduces recall cost mechanic.
function wesnoth.wml_actions.wc2_set_recall_cost(cfg)
	for i,u in ipairs(wesnoth.units.find_on_map { side = "1,2,3,4" }) do
		add_rc_object(u)
	end
	-- WC3: units left on the recall list keep the cost they were saved with otherwise
	for i,u in ipairs(wesnoth.units.find_on_recall { side = "1,2,3,4" }) do
		add_rc_object(u)
	end
end
