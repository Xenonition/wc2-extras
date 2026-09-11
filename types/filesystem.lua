---@meta
--- filesystem module type stubs for Wesnoth 1.18

---@class filesystem
filesystem = {}

---@param path string
---@return boolean
function filesystem.have_file(path) end

---@param path string
---@return string?
function filesystem.read_file(path) end
