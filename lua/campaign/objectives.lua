--creates the objectives of the wc2 scenarios.

local _ = wesnoth.textdomain 'wesnoth-wc'
local _lib = wesnoth.textdomain 'wesnoth-lib'
local strings = {
	wct_victory_condition = _"Defeat all enemy leaders and commanders",
	turns = _"Turns run out",
	wct_defeat_condition = _ "Lose your leader and all your commanders",
	difficulty = _lib("Difficulty: "),
	help_available = _ "An in-game help is available: right-click on any empty hex.",
}

function wesnoth.wml_actions.wc2_objectives(cfg)
	local win_desc = strings.wct_victory_condition
	if wc2x and wc2x.final_boss and wc2x.final_boss.is_boss_phase() then
		local boss_name = wml.variables["wc2x_boss_name"] or "the Final Boss"
		win_desc = _ "Defeat " .. boss_name
	end

	local objectives = {
		wml.tag.objective {
			description = win_desc,
			condition = "win",
		},
		wml.tag.objective {
			description = strings.turns,
			condition = "lose",
		},
		wml.tag.objective {
			description = strings.wct_defeat_condition,
			condition = "lose",
		},
		wml.tag.note {
			description = strings.difficulty .. (wml.variables["wc2_difficulty.name"] or ""),
		},
		note = wc2_color.help_text(strings.help_available)
	}
	local boss_status = wc2x and wc2x.final_boss and wc2x.final_boss.status_text()
	if boss_status then
		table.insert(objectives, wml.tag.note { description = boss_status })
	end
	wesnoth.wml_actions.objectives(objectives)
end
