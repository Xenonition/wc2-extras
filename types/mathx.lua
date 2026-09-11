---@meta
--- mathx module type stubs for Wesnoth 1.18

---@class mathx
mathx = {}

---@param max integer
---@return integer
---@overload fun(min: integer, max: integer): integer
function mathx.random(max) end

---@param list any[] Shuffled in-place
function mathx.shuffle(list) end
