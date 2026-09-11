---@meta
--- Wesnoth 1.18 Lua API type stubs for LuaLS
--- Grow these as we encounter new runtime bugs — see CONTRIBUTING note at bottom.

-----------------------------------------------------------
-- Core engine table
-----------------------------------------------------------

---@class wesnoth
---@field current wesnoth.current
---@field sides wesnoth.side[]
---@field unit_types table<string, wesnoth.unit_type>
---@field races table<string, wesnoth.race>
---@field scenario wesnoth.scenario_info
---@field map wesnoth.map
---@field game_events wesnoth.game_events
---@field interface wesnoth.interface
---@field units wesnoth.units_module
---@field sync wesnoth.sync
wesnoth = {}

---@param path string
---@return any
function wesnoth.dofile(path) end

---@param path string
---@return any
function wesnoth.require(path) end

---@param domain string
---@return fun(str: string): string
function wesnoth.textdomain(domain) end

---@param value boolean
function wesnoth.allow_undo(value) end

---@param type_id string
function wesnoth.add_known_unit(type_id) end

---@class wesnoth.current
---@field side integer
---@field turn integer
---@field event_context wesnoth.event_context
---@field map wesnoth.map_proxy

---@class wesnoth.event_context
---@field x1 integer?
---@field y1 integer?
---@field x2 integer?
---@field y2 integer?

---@class wesnoth.scenario_info
---@field turns integer

-----------------------------------------------------------
-- Sides
-----------------------------------------------------------

---@class wesnoth.side
---@field side integer
---@field gold integer
---@field recall_cost integer
---@field recruit string[] Array of unit type IDs (NOT a comma-separated string)
---@field variables table<string, any>
---@field name string

---@class wesnoth.sides
---@field find fun(filter: table): wesnoth.side[]
local _sides = {}

-----------------------------------------------------------
-- Units
-----------------------------------------------------------

---@class wesnoth.units_module
local _units = {}

---@param x integer
---@param y integer
---@return wesnoth.unit?
---@overload fun(id: string): wesnoth.unit?
function _units.get(x, y) end

---@param filter table
---@return wesnoth.unit[]
function _units.find_on_map(filter) end

---@param cfg table
---@return wesnoth.unit
function _units.create(cfg) end

---@class wesnoth.unit
---@field x integer
---@field y integer
---@field side integer
---@field type string
---@field name string
---@field canrecruit boolean
---@field experience integer
---@field max_experience integer
---@field hitpoints integer
---@field max_hitpoints integer
---@field moves integer
---@field max_moves integer
---@field variables table<string, any>
---@field __cfg table
local _unit = {}

---@param category string
---@param modification table
function _unit:add_modification(category, modification) end

---@param animate boolean?
---@param fire_events boolean?
function _unit:advance(animate, fire_events) end

function _unit:erase() end

---@class wesnoth.unit_type
---@field name string
---@field image string
---@field race string Race ID string
---@field level integer
---@field cost integer
---@field max_hitpoints integer
---@field max_experience integer
---@field max_moves integer
---@field alignment string "lawful"|"neutral"|"chaotic"|"liminal"
---@field advances_to string[]
---@field attacks wesnoth.attack_type[]

---@class wesnoth.attack_type
---@field description string
---@field damage integer
---@field number integer
---@field type string
---@field range string "melee"|"ranged"

---@class wesnoth.race
---@field name string

-----------------------------------------------------------
-- Map
-----------------------------------------------------------

---@class wesnoth.map
local _map = {}

---Returns 6 adjacent hex locations.
---@param x integer
---@param y integer
---@return wesnoth.location, wesnoth.location, wesnoth.location, wesnoth.location, wesnoth.location, wesnoth.location
---@overload fun(loc: wesnoth.location): wesnoth.location, wesnoth.location, wesnoth.location, wesnoth.location, wesnoth.location, wesnoth.location
function _map.get_adjacent_hexes(x, y) end

---@param filter table
---@return wesnoth.location[]
function _map.find(filter) end

---@param loc1 wesnoth.location|integer
---@param loc2 wesnoth.location|integer
---@return integer
function _map.distance_between(loc1, loc2) end

---@param loc wesnoth.location
---@param side integer
---@param fire_event boolean?
function _map.set_owner(loc, side, fire_event) end

---@class wesnoth.location
---@field x integer
---@field y integer

---@class wesnoth.map_proxy
---@field playable_width integer
---@field playable_height integer
---@field border_size integer
---@field [wesnoth.location] string Terrain code at location

-----------------------------------------------------------
-- Interface
-----------------------------------------------------------

---@class wesnoth.interface
local _iface = {}

---@param x integer
---@param y integer
---@return table[] Array of item tables
function _iface.get_items(x, y) end

---@param x integer
---@param y integer
---@param name string?
function _iface.remove_item(x, y, name) end

---@param x integer
---@param y integer
---@param text string
function _iface.float_label(x, y, text) end

-----------------------------------------------------------
-- Game events
-----------------------------------------------------------

---@class wesnoth.game_events
local _events = {}

---@param name string
---@param func fun(ec: wesnoth.event_context)
---@return function
function _events.add_repeating(name, func) end

---@param name string
---@param x integer?
---@param y integer?
---@return boolean
function _events.fire(name, x, y) end

-----------------------------------------------------------
-- Sync
-----------------------------------------------------------

---@class wesnoth.sync
local _sync = {}

---@param description string
---@param func fun(): table
---@return table
function _sync.evaluate_single(description, func) end

-----------------------------------------------------------
-- WML actions (partial — add as needed)
-----------------------------------------------------------

---@class wesnoth.wml_actions
---@field message fun(cfg: table)
---@field unit fun(cfg: table)
---@field item fun(cfg: table)
---@field label fun(cfg: table)
---@field lift_fog fun(cfg: table)
---@field open_help fun(cfg: table)
---@field recall fun(cfg: table)
---@field allow_recruit fun(cfg: table)
---@field set_recruit fun(cfg: table)
---@field event fun(cfg: table)
---@field wc2_objectives fun(cfg: table)
---@field wc2_set_recall_cost fun(cfg: table)
---@field wc2_fix_colors fun(cfg: table)
wesnoth.wml_actions = {}

-----------------------------------------------------------
-- CONTRIBUTING: When you hit a runtime error that LuaLS
-- would have caught, add the relevant type here. Keep
-- stubs minimal — only fields/signatures we actually use.
-----------------------------------------------------------
