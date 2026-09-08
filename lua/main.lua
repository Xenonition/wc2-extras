-- WC2 Extras — main entry point
-- Loads all mod modules. Called from _main.cfg via [lua] dofile.
-- Uses wesnoth.dofile so each module gets its own environment with
-- relative require paths resolved from this directory.

wc2x = {}

local addon_lua_path = "~add-ons/wc2-extras/lua/"

wc2x.config = wesnoth.dofile(addon_lua_path .. "config.lua")
wc2x.upgrades = wesnoth.dofile(addon_lua_path .. "upgrades.lua")
wc2x.economy = wesnoth.dofile(addon_lua_path .. "economy.lua")
wc2x.poi = wesnoth.dofile(addon_lua_path .. "poi.lua")
wc2x.shop = wesnoth.dofile(addon_lua_path .. "shop.lua")
