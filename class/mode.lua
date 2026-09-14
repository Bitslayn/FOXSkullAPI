---@class FOXSkull.Mode
---@field private __index FOXSkull.Mode
local class = {}
class.__index = class

---@param name string
---@param filter FOXSkull.Filter?
---@return FOXSkull.Mode
return function(name, filter)
	return setmetatable({}, class)
end