---@class FOXSkull.SkullMode
---@field render fun(delta: number, skull: FOXSkull.Skull, ctx: Event.SkullRender.context)
---@field init fun(skull: FOXSkull.Skull)
---@field private name string
---@field private key integer
---@field private filter FOXSkull.SkullFilter
---@field private __index FOXSkull.SkullMode
local class = {}
class.__index = class

---@diagnostic disable: invisible

local lib = {}

---@type FOXSkull.SkullMode[]
---@diagnostic disable-next-line: missing-fields
lib.modes = { [1] = { name = "default", key = 1, filter = {}, render = function() end, init = function() end } }

---Prevents any new skulls from being initialized with this mode
function class:remove()
	table.remove(lib.modes, self.key)
end

---@param name string
---@param filter FOXSkull.SkullFilter?
---@return FOXSkull.SkullMode
function lib.newMode(name, filter)
	local key = #lib.modes + 1
	lib.modes[key] = setmetatable({
		name = name,
		key = key,
		filter = filter or {},
		render = function() end,
		init = function() end,
	}, class)

	return lib.modes[key]
end

---@param skull FOXSkull.Skull
---@return FOXSkull.SkullMode
function lib.matchMode(skull)
	for i = #lib.modes, 1, -1 do
		local mode = lib.modes[i]

		local match = true

		for j = 1, #mode.filter do
			if not mode.filter[j](skull) then
				match = false
				break
			end
		end

		if match then
			return mode
		end
	end

	return lib.modes[1]
end

return lib
