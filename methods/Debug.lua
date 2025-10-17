---@diagnostic disable: undefined-field
---@meta FOXSkull

---@class FOXSkull.any
local anyClass = require("../FOXSkull").class

---Catches an internal skull error
---
---Functions the same as a pcall
---@generic self
---@param self self
---@param f function
---@param ... any
---@return self
function anyClass:try(f, ...)
	local success, result = pcall(f, ...)
	if success then return self end

	result = "§c" .. tostring(result)
		:gsub("\9", "  ")
	-- :gsub("[^\n]*SkullAPI.*$", "  [SkullAPI]: in ?")

	self[1].error = result

	return self
end