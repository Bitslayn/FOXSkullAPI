---@class FOXSkull.Filter
---@field private [number] FOXSkull.Filter.func
---@field private __index FOXSkull.Filter
local class = {}
class.__index = class

---@alias FOXSkull.Filter.func fun(skull: FOXSkull.Skull): (match: boolean)

---@param name string
---@return self
function class:withName(name)
	self[#self + 1] = function(skull)
		return skull.name == name
	end
	return self
end

---@return FOXSkull.Filter
return function()
	return setmetatable({}, class)
end
