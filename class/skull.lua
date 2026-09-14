---@class FOXSkull.Skull
---@field name string
---@field model ModelPart
---@field private render fun(delta: number, skull: FOXSkull.Skull, ctx: Event.SkullRender.context)
---@field private __index FOXSkull.Skull
local class = {}
class.__index = class

local lib = {}

lib.defaultModel = models:newPart("Skull")
lib.blockHash = vec(1, 999, 9999999)

---@param tbl table
---@param key string
---@param block BlockState
---@return FOXSkull.Skull
function lib.newBlock(tbl, key, block)
	local nbt = block:getEntityData()

	tbl[key] = setmetatable({
		name = nbt and nbt.display and nbt.display.Name,
		model = lib.defaultModel,
		render = function() end,
	}, class)

	return tbl[key]
end

---@param tbl table
---@param key string
---@param item ItemStack
---@return FOXSkull.Skull
function lib.newItem(tbl, key, item)
	tbl[key] = setmetatable({
		name = item:getName(),
		model = lib.defaultModel,
		render = function() end,
	}, class)

	return tbl[key]
end

return lib
