---@class FOXSkull.Skull
---@field name string
---@field ctx string
---@field private __index FOXSkull.Skull
local class = {}
class.__index = class

---@class FOXSkull.Skull.Block: FOXSkull.Skull
---@class FOXSkull.Skull.Item: FOXSkull.Skull
---@alias FOXSkull.Skull.Any FOXSkull.Skull.Block|FOXSkull.Skull.Item

local lib = {}

---@param b BlockState
---@return FOXSkull.Skull.Block
function lib.newBlock(b)
	local nbt = b:getEntityData()
	return setmetatable({
		name = nbt and nbt.display and nbt.display.Name
	}, class) --[[@as FOXSkull.Skull.Block]]
end

---@param i ItemStack
---@return FOXSkull.Skull.Item
function lib.newItem(i)
	return setmetatable({
		name = i:getName()
	}, class) --[[@as FOXSkull.Skull.Item]]
end

return lib
