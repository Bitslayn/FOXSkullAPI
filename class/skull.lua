---@class FOXSkull.Skull: FOXSkull.SkullMode
---@field name string
---@field model ModelPart
---@field render fun(delta: number, skull: FOXSkull.Skull, ctx: Event.SkullRender.context)
---@field init fun(skull: FOXSkull.Skull)
---@field private __index FOXSkull.Skull
local class = {}
class.__index = class

local lib = {}

local mode = require("./mode")

lib.defaultModel = models:newPart("Skull")
lib.blockHash = vec(1, 999, 9999999)

---@param tbl table
---@param key string
---@param block BlockState
---@return FOXSkull.Skull
function lib.newBlock(tbl, key, block)
	local nbt = block:getEntityData()

	tbl[key] = {
		name = nbt and nbt.display and nbt.display.Name or "Player Head",
		model = lib.defaultModel,
	}

	setmetatable(tbl[key], { __index = mode.matchMode(tbl[key]) })

	tbl[key].init(tbl[key])

	return tbl[key]
end

---@param tbl table
---@param key string
---@param item ItemStack
---@return FOXSkull.Skull
function lib.newItem(tbl, key, item)
	tbl[key] = {
		name = item:getName(),
		model = lib.defaultModel,
	}

	setmetatable(tbl[key], { __index = mode.matchMode(tbl[key]) })

	tbl[key].init(tbl[key])

	return tbl[key]
end

return lib
