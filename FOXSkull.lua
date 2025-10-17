---@meta FOXSkull

--#REGION ˚♡ Class ♡˚

---Internal variables not to be accessed outside of developing FOXSkullAPI!
---@class FOXSkull.any.private
---@field model ModelPart?
---@field timestamp number
---@field visible boolean?
---@field uuid string
---@field error string?
---@field contexts {[string]: any[]}

---@alias FOXSkull.block.context
---| "BLOCK"                   Placed as a block
---| "OTHER"                   Some other context
---@alias FOXSkull.item.context
---| "HEAD"                    Worn on head
---| "FIRST_PERSON_RIGHT_HAND" Held in right hand in first person
---| "FIRST_PERSON_LEFT_HAND"  Held in left hand in first person
---| "THIRD_PERSON_RIGHT_HAND" Held in right hand in third person or to viewers
---| "THIRD_PERSON_LEFT_HAND"  Held in left hand in third person or to viewers
---| "ITEM_ENTITY"             Dropped on the ground
---| "ITEM_FRAME"              Held in item frame
---| "GUI"	                   Stored in container or inventory
---| "OTHER"                   Some other context. Used for ITEM_ENTITY, ITEM_FRAME, and GUI on 0.1.5 and
---@alias FOXSkull.any.context FOXSkull.block.context|FOXSkull.item.context

---@alias FOXSkull.block.render fun(delta: number, self: FOXSkull.block)
---@alias FOXSkull.item.render fun(delta: number, self: FOXSkull.item)
---@alias FOXSkull.any.render fun(delta: number, self: FOXSkull.any)
---@alias FOXSkull.block.tick fun(self: FOXSkull.block)
---@alias FOXSkull.item.tick fun(self: FOXSkull.item)
---@alias FOXSkull.any.tick fun(self: FOXSkull.any)

---Represents a skull placed in loaded chunks
---@class FOXSkull.block: FOXSkull.any
---@field block BlockState
---@field context FOXSkull.block.context
---@field render FOXSkull.block.render?
---@field tick FOXSkull.block.tick?
---Represents a unique skull item being rendered
---@class FOXSkull.item: FOXSkull.any
---@field item ItemStack
---@field entity Entity
---@field context FOXSkull.item.context
---@field render FOXSkull.item.render?
---@field tick FOXSkull.item.tick?
---Represents any skull, block or item, that's rendered
---@class FOXSkull.any
---@field context FOXSkull.any.context
---@field render FOXSkull.any.render?
---@field tick FOXSkull.any.tick?
---@field package [1] FOXSkull.any.private
---@field package __index FOXSkull.any


---@class FOXSkull.any
local class = {}
---@alias FOXSkull.key.internalID string
---@type table<FOXSkull.key.internalID, FOXSkull.any>
local all = {}
---@class FOXSkull
local skull = { class = class, all = all }

---@alias FOXSkull.key.uuid string
---@type table<FOXSkull.key.uuid, FOXSkull.key.internalID>
local uuids = {}

---@type FOXSkullAPI.Events, FOXSkullAPI.Events.call
local _, call = require("./util/Events")

--#ENDREGION
--#REGION ˚♡ Get ♡˚

local idSwitch = {
	---@param key string
	---@return FOXSkull.key.internalID
	string = function(key)
		return uuids[key]
	end,
	---@param key BlockState
	---@return FOXSkull.key.internalID
	BlockState = function(key)
		return key:getPos():toString()
	end,
	---@param key ItemStack
	---@return FOXSkull.key.internalID
	ItemStack = function(key)
		return key:toStackString() .. key:getCount()
	end,
	---@param key Vector3
	---@return FOXSkull.key.internalID
	Vector3 = function(key)
		return key:toString()
	end,
}

---@param key string|BlockState|ItemStack|Vector3
---@return FOXSkull.key.internalID?
local function getID(key)
	local switch = idSwitch[type(key)]
	if not switch then return end
	return switch(key)
end

---@overload fun(key: string): FOXSkull.any?
---@overload fun(key: BlockState): FOXSkull.block?
---@overload fun(key: ItemStack): FOXSkull.item?
---@overload fun(key: Vector3): FOXSkull.block?
function skull.get(key)
	return all[getID(key) or key]
end

--#ENDREGION
--#REGION ˚♡ New ♡˚

local metaBlock = {
	__index = class,
	__type = "FOXSkull.block",
}
local metaItem = {
	__index = class,
	__type = "FOXSkull.item",
}

local newSwitch = {
	---@param key BlockState
	---@return FOXSkull.block
	BlockState = function(key)
		local block = key
		local self = setmetatable({}, metaBlock) --[[@as FOXSkull.block]]
		self.block = block
		return self
	end,
	---@param key ItemStack
	---@return FOXSkull.item
	ItemStack = function(key)
		local item = key
		local self = setmetatable({}, metaItem) --[[@as FOXSkull.item]]
		self.item = item:copy()
		return self
	end,
}

---@overload fun(key: BlockState): FOXSkull.block
---@overload fun(key: ItemStack): FOXSkull.item
function skull.new(key)
	local switch = newSwitch[type(key)]
	if not switch then return end

	local self = switch(key)
	local priv = {
		visible = true,
		uuid = client.intUUIDToString(client.generateUUID()),
		timestamp = client.getSystemTime(),
		contexts = {},
	}

	self[1] = priv

	local id = getID(key)
	uuids[priv.uuid] = id
	all[id] = self

	call.init(self)

	return self
end

--#ENDREGION
--#REGION ˚♡ Remove ♡˚

---@param key string|BlockState|ItemStack|Vector3
function skull.remove(key)
	local self = skull.get(key)
	if not self then return end

	call.deinit(self)

	uuids[self[1].uuid] = nil
	all[getID(key) or key] = nil

	if self[1].model then self[1].model:getParent():remove() end
end

--#ENDREGION

return skull
