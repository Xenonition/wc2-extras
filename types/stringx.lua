---@meta
--- stringx module type stubs for Wesnoth 1.18
--- NOTE: stringx.strip does NOT exist. Use Lua pattern matching for trimming.

---@class stringx
stringx = {}

---@param str string
---@param sep string? Separator (default ",")
---@return string[]
function stringx.split(str, sep) end

---@param fmt string Format string with $var placeholders
---@param values table<string, any>
---@return string
function stringx.vformat(fmt, values) end

-- stringx.strip DOES NOT EXIST in Wesnoth 1.18.
-- Use: str:match("^%s*(.-)%s*$") for trimming.

-- stringx.trim DOES NOT EXIST either.
