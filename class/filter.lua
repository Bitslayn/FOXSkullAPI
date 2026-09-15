---@class FOXSkull.SkullFilter
---@field private [number] FOXSkull.SkullFilter.func
---@field private __index FOXSkull.SkullFilter
local class = {}
class.__index = class

local lib = {}

---@alias FOXSkull.SkullFilter.func fun(skull: FOXSkull.Skull): (match: boolean)

---@param name string
---@return self
function class:withName(name)
	self[#self + 1] = function(skull)
		return skull.name:find(name) ~= nil
	end

	return self
end

---@return FOXSkull.SkullFilter
function lib.newFilter()
	return setmetatable({}, class)
end

return lib
