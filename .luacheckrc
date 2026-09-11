-- Luacheck config for World Conquest III (Wesnoth 1.18 mod)

std = "lua53"
max_line_length = false

-- Wesnoth engine globals (mutable — fields like wml.variables, wesnoth.sides are writable)
globals = {
	-- Core Wesnoth API
	"wesnoth",
	"wml",
	"gui",
	"mathx",
	"stringx",
	"filesystem",

	-- WC2 globals (set by base WC2 code)
	"wc2_era",
	"wc2_enemy",
	"wc2_scenario",
	"wc2_artifacts",
	"wc2_heroes",
	"wc2_training",
	"wc2_dropping",
	"wc2_invest",
	"wc2_color",
	"wc2_utils",
	"wc2_random_names",
	"wc2_convert",
	"wc2_show_invest_dialog",
	"wc2_show_invest_dialog_impl",

	-- WC3 global (set by campaign_main.lua)
	"wc2x",

	-- Common aliases
	"T",
	"on_event",
	"_G",
}

-- Ignore unused self/loop variables
ignore = {
	"21._",           -- unused variable starting with _
	"212",            -- unused argument
	"213",            -- unused loop variable
	"631",            -- line > max length (disabled above but just in case)
}

-- Base WC2 code: only lint for errors, not style — we don't own it
files["lua/campaign/**"] = { ignore = { "1" } }
files["lua/game_mechanics/**"] = { ignore = { "1" } }
files["lua/era/**"] = { ignore = { "1" } }
files["lua/map/**"] = { ignore = { "1" } }

-- Exclude vendored WC2 files from checks entirely
exclude_files = {
	"lua/on_event.lua",
}
