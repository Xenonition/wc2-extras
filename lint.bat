@echo off
echo === luacheck (globals, unused vars, Lua 5.3) ===
luacheck lua/wc2x/poi.lua lua/wc2x/shop.lua lua/wc2x/dialog_utils.lua lua/wc2x/upgrades.lua lua/wc2x/config.lua lua/campaign_main.lua
echo.
echo === lua-language-server (types, API signatures) ===
lua-language-server --check . --checklevel=Warning
