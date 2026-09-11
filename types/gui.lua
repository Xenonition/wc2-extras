---@meta
--- GUI module type stubs for Wesnoth 1.18

---@class gui
gui = {}

---@param wml_cfg table The [resolution] WML table
---@param preshow fun(dialog: gui.dialog)?
---@param postshow fun(dialog: gui.dialog)?
---@return integer Button result: -1 for ok, -2 for cancel
function gui.show_dialog(wml_cfg, preshow, postshow) end

---@param title string
---@param message string
---@param icon string?
function gui.show_prompt(title, message, icon) end

---@class gui.dialog
---@field [string] gui.widget Access child widgets by WML id

---@class gui.widget
---@field label string|number Widget label / image path / markup text
---@field selected_index integer 1-based selection index (listbox/multi_page)
---@field item_count integer Number of items (read-only)
---@field on_modified fun()? Selection change callback
---@field on_button_click fun()? Button click callback
---@field value integer Slider/spinner value
---@field text string Text input value
---@field selected boolean Toggle state
---@field unfolded boolean Tree node expanded state
---@field path integer[] Tree node path
---@field selected_item_path integer[] Tree view selected path
---@field [string] gui.widget Child widget access by id
---@field [integer] gui.widget Row access by 1-based index (listbox)
local _widget = {}

---@return gui.widget row The new row object
function _widget:add_item() end

---@param type string Node type id
---@return gui.widget node
function _widget:add_item_of_type(type) end

function _widget:focus() end

---@param index integer
---@param count integer?
function _widget:remove_items_at(index, count) end
