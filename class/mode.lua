---@class FOXSkull.Mode
---@field model ModelPart?
---@field render fun(delta: number, skull: FOXSkull.Skull, ctx: Event.SkullRender.context)
---@field private name string
---@field private __index FOXSkull.Mode
local class = {}
class.__index = class

local lib = {}

lib.modes = {}

---Prevents any new skulls from being initialized with this mode
function class:remove()
	lib.modes[self.name] = nil
end

---@param name string
---@param filter FOXSkull.Filter?
---@return FOXSkull.Mode
function lib.newMode(name, filter)
	lib.modes[name] = setmetatable({
		name = name,
		filter = filter,
	}, class)

	return lib.modes[name]
end

return lib
