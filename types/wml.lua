---@meta
--- WML module type stubs for Wesnoth 1.18

---@class wml
wml = {}

---@class wml.tag
---@field variables fun(cfg: table): table
---@field filter_side fun(cfg: table): table
---@field filter_location fun(cfg: table): table
---@field filter_radius fun(cfg: table): table
---@field filter_wml fun(cfg: table): table
---@field filter fun(cfg: table): table
---@field filter_attack fun(cfg: table): table
---@field has_unit fun(cfg: table): table
---@field option fun(cfg: table): table
---@field object fun(cfg: table): table
---@field effect fun(cfg: table): table
---@field modifications fun(cfg: table): table
---@field ai fun(cfg: table): table
---@field trait fun(cfg: table): table
---@field player_sides fun(cfg: table): table
---@field wc2_map_supply_village fun(cfg: table): table
---@field ["and"] fun(cfg: table): table
---@field ["not"] fun(cfg: table): table
wml.tag = {}

---@class wml.variables
---@field [string] any
wml.variables = {}

---@param path string
---@return table
function wml.load(path) end

---@param cfg table
---@param name string
---@param index integer?
---@return table?
function wml.get_child(cfg, name, index) end

---@param cfg table
---@param name string
---@return fun(): integer, table
function wml.child_range(cfg, name) end

---@param cfg table
---@return table
function wml.parsed(cfg) end

---@param msg string
function wml.error(msg) end
