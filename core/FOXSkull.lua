---@meta FOXSkull

--#REGION ˚♡ Class ♡˚

---@class FOXSkull.any.private
---@field model ModelPart?
---@field timestamp number
---@field visible boolean?
---@field uuid string
---@field error any?
---@field contexts {[string]: any[]}

---@alias FOXSkull.block.render fun(delta: number, self: FOXSkull.block)
---@alias FOXSkull.item.render fun(delta: number, self: FOXSkull.item)
---@alias FOXSkull.any.render fun(delta: number, self: FOXSkull.any)
---@alias FOXSkull.block.tick fun(self: FOXSkull.block)
---@alias FOXSkull.item.tick fun(self: FOXSkull.item)
---@alias FOXSkull.any.tick fun(self: FOXSkull.any)

---@class FOXSkull.block: FOXSkull.any
---@field block BlockState
---@field render FOXSkull.block.render?
---@field tick FOXSkull.block.tick?
---@class FOXSkull.item: FOXSkull.any
---@field item ItemStack
---@field entity Entity
---@field render FOXSkull.item.render?
---@field tick FOXSkull.item.tick?
---@class FOXSkull.any
---@field context Event.SkullRender.context
---@field render FOXSkull.any.render?
---@field tick FOXSkull.any.tick?
---@field package [1] FOXSkull.any.private
---@field package __index FOXSkull.any

---@class FOXSkull
local skull = {
	---@class FOXSkull.any
	class = {
		---Catches an internal skull error
		---
		---Functions the same as a pcall 
		---@generic self
		---@param self self
		---@param f function
		---@param ... any
		---@return self
		---@package
		try = function(self, f, ...)
			local success, result = pcall(f, ...)
			if not success then self[1].error = result and result:gsub("\9", "  ") or true end
			return self
		end,
	}
}

---@alias FOXSkull.key.internalID string
---@type table<FOXSkull.key.internalID, FOXSkull.any>
local all = {}

---@alias FOXSkull.key.uuid string
---@type table<FOXSkull.key.uuid, FOXSkull.key.internalID>
local uuids = {}

---@type FOXSkullAPI.Events, FOXSkullAPI.Events.call
local _, call = require("../util/Events")

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

local get = skull.get

--#ENDREGION
--#REGION ˚♡ New ♡˚

local metaBlock = {
	__index = skull.class,
	__type = "FOXSkull.block",
}
local metaItem = {
	__index = skull.class,
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

local new = skull.new

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

local remove = skull.remove

--#ENDREGION
--#REGION ˚♡ Render ♡˚

local vanillaSkull = models:newPart("vanillaSkull", "Skull"):visible(false)
local skullItem = vanillaSkull:newItem("Skull")
	:pos(0, 8, 0)
	:item("minecraft:player_head")

pcall(skullItem.item, skullItem, "minecraft:player_head" .. toJson { SkullOwner = avatar:getEntityName() })

local blank = textures:newTexture("", 1, 1)

local invisibleSkull = models:newPart("invisibleSkull", "Skull"):visible(false)
invisibleSkull:newSprite("Sprite"):setTexture(blank)

---@type ModelPart
local model
---@type number
local sharedDelta
function events.skull_render(delta, block, item, entity, context)
	---@type FOXSkull.any
	local self = get(block or item) or new(block or item)
	local priv = self[1]

	local time = client.getSystemTime()
	if priv.timestamp ~= time and sharedDelta ~= delta then
		priv.contexts = {}
	end
	priv.timestamp = time
	sharedDelta = delta

	self.block = block
	self.item = item
	self.entity = entity
	self.context = context

	priv.contexts[context] = { entity }

	if model then model:visible(false) end
	model = nil

	if priv.error then
		model = vanillaSkull
	elseif priv.visible then
		if priv.flatModel and (context == "GUI" or context == "OTHER") then
			model = priv.flatModel
		elseif priv.bakedModel and not priv.model then
			local mat = priv.itemMats[context]
			if mat then priv.bakedPivot:matrix(mat) end
			model = priv.bakedModel
		else
			model = priv.model
		end
	else
		model = invisibleSkull
	end

	if model then model:visible(true) end

	if self.render and not priv.error then
		self:try(self.render, delta, self)
	end
end

--#ENDREGION
--#REGION ˚♡ Tick ♡˚

function events.world_tick()
	for _, self in pairs(all) do
		local priv = self[1]
		if self.tick and not priv.error then
			for _, params in pairs(priv.contexts) do
				self.entity = params[1]
				self:try(self.tick, self)
			end
		end
	end
end

--#ENDREGION
--#REGION ˚♡ Flush ♡˚

---@type FOXSkull.key.internalID
local key
function events.skull_render()
	key = next(all, key)
	local self = all[key]
	if not self then return end

	local block = self --[[@as FOXSkull.block]].block

	local timer = block and 50 or 2000
	if client.getSystemTime() - self[1].timestamp < timer then return end

	if block then
		local pos = block:getPos()
		if world.isChunkLoaded(pos) and world.getBlockState(pos) == block then return end
	end

	remove(key)
	key = nil
end

--#ENDREGION

return skull
