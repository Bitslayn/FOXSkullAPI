--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's SkullAPI v1.0.0-dev
]]

--==============================================================================================================================
--#REGION ˚♡ FOXSkull ♡˚
--==============================================================================================================================

---@class FOXSkull
local skull = {}

---Internal variables not to be accessed outside of developing FOXSkullAPI!
---@class FOXSkull.any.private
---@field model ModelPart?
---@field timestamp number
---@field visible boolean?
---@field uuid string
---@field error string?
---@field contexts {[FOXSkull.any.context]: any[]} Used for the tick event to run it on every item context. The table stores all the variables that should be set that context, currently only having to set the entity

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

---Represents any skull, block or item, that's rendered
---@class FOXSkull.any
---@field context FOXSkull.any.context
---@field render FOXSkull.any.render?
---@field tick FOXSkull.any.tick?
---@field package [1] FOXSkull.any.private
---@field package __index FOXSkull.any
local anyClass = {}
---Represents a skull placed in loaded chunks
---@class FOXSkull.block: FOXSkull.any
---@field block BlockState
---@field context FOXSkull.block.context
---@field render FOXSkull.block.render?
---@field tick FOXSkull.block.tick?
local blockClass = anyClass
---Represents a unique skull item being rendered
---@class FOXSkull.item: FOXSkull.any
---@field item ItemStack
---@field entity Entity
---@field context FOXSkull.item.context
---@field render FOXSkull.item.render?
---@field tick FOXSkull.item.tick?
local itemClass = anyClass

---The internal string ID which differs based on skull context
---
---**BlockState|Vector3 => "{\<x\>, \<y\>, \<z\>}"**
---
---Stringifies the block position
---
---**ItemStack => "minecraft:player_head{\<NBT\>}\<count\>"**
---
---Concatenates the stack string with the item count
---@alias FOXSkull.key.internalID string
---A generic, non-strict, key used to index a skull.
---@alias FOXSkull.key.genericKey FOXSkull.key.uuid|BlockState|ItemStack|Vector3
---@type table<FOXSkull.key.internalID, FOXSkull.any>
local all = {}

---A string UUID
---@alias FOXSkull.key.uuid string
---@type table<FOXSkull.key.uuid, FOXSkull.key.internalID>
local uuids = {}

------------------------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Methods ♡˚
------------------------------------------------------------------------------------------------

---------- ˚♡ Blocks ♡˚ ----------

local dirs = {
	east  = vec(1, 0, 0),
	west  = vec(-1, 0, 0),
	floor = vec(0, 1, 0),
	south = vec(0, 0, 1),
	north = vec(0, 0, -1),
}

---Gets the block this skull is placed on
---@param distance number?
---@param invert boolean?
---@return BlockState
---@nodiscard
function blockClass:getAttachedBlock(distance, invert)
	local block = self.block

	distance = distance or 1
	invert = invert and -1 or 1

	local facing = block.properties.facing
	local pos = block:getPos() - (dirs[facing] or dirs.floor) * invert * distance
	return world.getBlockState(pos)
end

---Gets the visual center position of this skull in the world
---@return Vector3
---@nodiscard
function blockClass:getCenterPos()
	local block = self.block

	local shape = block:getOutlineShape()[1]
	local center = math.lerp(shape[1], shape[2], 0.5) + block:getPos()
	if self[1].model then center = center + self[1].model:getPos() / 16 end
	return center
end

---Gets the direction this skull is facing
---@return Vector3
---@nodiscard
function blockClass:getDir()
	local block = self.block

	local rot = tonumber(block.properties.rotation)
	if rot then
		local yaw = math.rad(rot * -22.5 - 180)
		return vec(math.sin(yaw), 0, math.cos(yaw))
	else
		local facing = block.properties.facing
		return dirs[facing]
	end
end

---Aligns the skull model to the floor below it
---@param distance number
---@return self
function blockClass:alignToFloor(distance)
	if not self[1].model then return self end

	distance = distance or 1.25

	local startPos = self.block:getOutlineShape()[1][1] + self.block:getPos()
	local endPos = startPos - vec(0, distance, 0)

	local _, hit = raycast:block(startPos, endPos, "OUTLINE", "NONE")
	if hit == endPos then return self end
	self[1].model:pos(0, (startPos - hit):length() * -16)

	return self
end

---@return integer
---@nodiscard
function blockClass:getRedstoneLevel()
	local pos = self.block:getPos()
	local level = world.getRedstonePower(pos)

	return level
end

---------- ˚♡ Model ♡˚ ----------

---Sets the model to render for this skull
---@generic self
---@param self self
---@param model ModelPart?
---@return self
function anyClass:setModel(model)
	local priv = self[1]

	if not model then
		if not priv.model then return self end
		priv.model:getParent():remove()
		return self
	end

	local pivot
	if priv.model then
		pivot = priv.model
			:getParent()
			:pos(-model:getPivot())

		priv.model:remove()
	else
		pivot = models
			:newPart("skullPivot")
			:parentType("Skull")
			:pos(-model:getPivot())
	end

	priv.model = model
		:copy("skullModel")
		:moveTo(pivot)
		:visible(false)

	return self
end

---Sets the model to render for this skull
---@generic self
---@param self self
---@param model ModelPart?
---@return self
function anyClass:model(model)
	return self --[[@as FOXSkull.any]]:setModel(model)
end

---Gets the model set to render for this skull
---@return ModelPart
---@nodiscard
function anyClass:getModel()
	return self[1].model
end

---------- ˚♡ Data ♡˚ ----------

local defaultName = avatar:getEntityName() .. "'s Head"

---@param json string
---@return string
local function parseName(json)
	local name = parseJson(json)
	return name.text or name
end

---Gets the name of this skull from its block or item data
---@generic self
---@param self self
---@return string
---@nodiscard
function anyClass:getName()
	if self --[[@as FOXSkull.item]].item then
		return self --[[@as FOXSkull.item]].item:getName()
	else
		local block = self --[[@as FOXSkull.block]].block
		local data = block:getEntityData()
		if not data then return defaultName end
		return data.custom_name and parseName(data.custom_name) or defaultName -- Block for 1.21+
	end
end

local function parseLore(tbl)
	local lore = {}

	for _, line in ipairs(tbl) do
		local lineJson = parseJson(line)

		if type(lineJson) == "table" then
			local text = ""

			-- NBT <1.20.5

			for _, sectJson in ipairs(lineJson) do
				text = text .. (sectJson.text or sectJson)
			end

			-- Components 1.20.5+

			if lineJson.text then
				text = text .. lineJson.text
				for _, sectJson in ipairs(lineJson.extra) do
					text = text .. (sectJson.text or sectJson)
				end
			end

			lineJson = text
		end

		table.insert(lore, lineJson.text or lineJson)
	end

	return table.concat(lore, "\n")
end

---Gets the lore of this skull from its item data
---@return string?
---@nodiscard
function itemClass:getLore()
	local tag = self.item.tag
	local lines = tag.display and tag.display.Lore or tag.lore or tag["minecraft:lore"]
	if not lines then return end
	return parseLore(lines)
end

---@param str string
local function parseBase64(str)
	local buffer = data:createBuffer()
	buffer:writeBase64(str)
	buffer:setPosition(0)
	local decoded = buffer:readByteArray()
	buffer:close()
	return decoded
end

---@param textures table
---@return string
local function parseTextures(textures)
	local data = {}
	for i, texture in ipairs(textures) do
		data[i] = parseBase64(texture.value or texture.Value)
	end
	return table.concat(data, "")
end

---Gets this skull's parsed texture data
---@generic self
---@param self self
---@return string
---@nodiscard
function anyClass:getData()
	local block = self --[[@as FOXSkull.block]].block
	local item = self --[[@as FOXSkull.item]].item
	local nbt = block and block:getEntityData() or item and item.tag
	if not nbt then return "" end

	local textures = nbt.SkullOwner and nbt.SkullOwner.Properties and nbt.SkullOwner.Properties.textures or -- < 1.21.9
		nbt.profile and nbt.profile.properties                                                           -- 1.21.9+

	return textures and parseTextures(textures) or ""
end

---------- ˚♡ Visibility ♡˚ ----------

---Sets this skull's visibility
---@generic self
---@param self self
---@param state boolean?
---@return self
function anyClass:setVisible(state)
	self[1].visible = state == nil and true or state
	return self
end

---Sets this skull's visibility
---@generic self
---@param self self
---@param state boolean?
---@return self
function anyClass:visible(state)
	return self --[[@as FOXSkull.any]]:setVisible(state)
end

---Gets this skull's visibility
---@return boolean
---@nodiscard
function anyClass:getVisible()
	return self[1].visible
end

---------- ˚♡ Functions ♡˚ ----------

---Sets the function to run when this skull renders
---@overload fun(self: FOXSkull.block, func: FOXSkull.block.render): FOXSkull.block
---@overload fun(self: FOXSkull.item, func: FOXSkull.item.render): FOXSkull.item
---@overload fun(self: FOXSkull.any, func: FOXSkull.any.render): FOXSkull.any
function anyClass:setRender(func)
	self.render = func
	return self
end

---Sets the function to run when this skull ticks
---@overload fun(self: FOXSkull.block, func: FOXSkull.block.tick): FOXSkull.block
---@overload fun(self: FOXSkull.item, func: FOXSkull.item.tick): FOXSkull.item
---@overload fun(self: FOXSkull.any, func: FOXSkull.any.render): FOXSkull.any
function anyClass:setTick(func)
	self.tick = func
	return self
end

---------- ˚♡ UUID ♡˚ ----------

---Gets this skull's uuid
---@return string
---@nodiscard
function anyClass:getUUID()
	return self[1].uuid
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Error Handling ♡˚
------------------------------------------------------------------------------------------------

---Catches an internal skull error
---
---Functions the same as a pcall
---@generic self
---@param self self
---@param f function
---@param ... any
---@return self
local function try(self, f, ...)
	local success, result = pcall(f, ...)
	if success then return self end

	result = "§c[error] §f" .. avatar:getEntityName() .. "§c : " .. tostring(result)
		:gsub("\9", "  ")
		:gsub("[^\n]*'pcall'.-$", "  [SkullAPI]: in ?")

	self[1].error = result

	return self
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Events ♡˚
------------------------------------------------------------------------------------------------

---@alias FOXSkullAPI.Events.block fun(skull: FOXSkull.block)
---@alias FOXSkullAPI.Events.item fun(skull: FOXSkull.item)
---@class FOXSkullAPI.Events
local skullEvents = {
	---@type FOXSkullAPI.Events.block[]
	block_init = {},
	---@type FOXSkullAPI.Events.item[]
	item_init = {},
	---@type FOXSkullAPI.Events.block[]
	block_deinit = {},
	---@type FOXSkullAPI.Events.item[]
	item_deinit = {},
}

---@param self FOXSkull.any
---@param state boolean
local function init(self, state)
	local t = type(self)
	local k = t:sub(10, #t) .. (state and "_init" or "_deinit")

	try(self, function()
		---@diagnostic disable-next-line: param-type-mismatch
		for _, func in pairs(skullEvents[k]) do func(self) end
	end)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Accessor ♡˚
------------------------------------------------------------------------------------------------

---------- ˚♡ Get ♡˚ ----------

local idSwitch = {
	---@param key FOXSkull.key.uuid
	---@return FOXSkull.key.internalID
	string = function(key) return uuids[key] end,
	---@param key BlockState
	---@return FOXSkull.key.internalID
	BlockState = function(key) return key:getPos():toString() end,
	---@param key ItemStack
	---@return FOXSkull.key.internalID
	ItemStack = function(key) return key:toStackString() .. key:getCount() end,
	---@param key Vector3
	---@return FOXSkull.key.internalID
	Vector3 = function(key) return key:toString() end,
}

---Formats a supported key into an internalID
---
---Returns nil if the key is of an invalid type
---@param key FOXSkull.key.genericKey
---@return FOXSkull.key.internalID?
local function getID(key)
	local switch = idSwitch[type(key)]
	if not switch then return end
	return switch(key)
end

---Gets a skull that has been initialized
---
---Returns nil if a skull with the given key does not exist
---@overload fun(key: FOXSkull.key.uuid): FOXSkull.any?
---@overload fun(key: BlockState): FOXSkull.block?
---@overload fun(key: ItemStack): FOXSkull.item?
---@overload fun(key: Vector3): FOXSkull.block?
function skull.get(key)
	return all[getID(key) or key]
end

local get = skull.get

---------- ˚♡ New ♡˚ ----------

local metaBlock = {
	__index = anyClass,
	__type = "FOXSkull.block",
}
local metaItem = {
	__index = anyClass,
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

---Creates and returns a new skull with the given BlockState or ItemStack
---
---Calls the init event
---
---Returns nil if the key is of an invalid type
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

	init(self, true)

	return self
end

local new = skull.new

---------- ˚♡ Remove ♡˚ ----------

---Removes a skull by its generic key
---
---Calls the deinit event
---@param key FOXSkull.key.genericKey
function skull.remove(key)
	local self = skull.get(key)
	if not self then return end

	init(self, false)

	uuids[self[1].uuid] = nil
	all[getID(key) or key] = nil

	if self[1].model then self[1].model:getParent():remove() end
end

local remove = skull.remove

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Process ♡˚
------------------------------------------------------------------------------------------------

---------- ˚♡ Render ♡˚ ----------

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
	-- Update vars

	---@type BlockState|ItemStack
	local this = block or item

	---@type FOXSkull.any
	local self = get(this) or new(this)
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
	---@diagnostic disable-next-line: assign-type-mismatch
	self.context = context

	priv.contexts[context] = { entity }


	-- Skull is rendering, run its render function

	if self.render and not priv.error then
		try(self, self.render, delta, self, this)
	end


	-- Update the skull's model

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
end

---------- ˚♡ Tick ♡˚ ----------

function events.world_tick()
	for _, self in pairs(all) do
		local priv = self[1]
		if self.tick and not priv.error then
			for _, params in pairs(priv.contexts) do
				self.entity = params[1]
				try(self, self.tick, self)
			end
		end
	end
end

---------- ˚♡ Flush ♡˚ ----------

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

---------- ˚♡ Outline ♡˚ ----------

local mat = matrices.mat4()
mat.c4 = vec(0, 0.5, 0, 0.125)

---@param color Vector3|Vector4?
---@param icon string?
---@return ModelPart
local function newOutline(color, icon)
	local outline = models:newPart("skullOutline", "Skull")
		:visible(false)
		:matrix(mat)

	for axis = 0, 2 do
		for rot = 0, 3 do
			local turn = math.floor(axis / 2)
			local lineMat = matrices.mat4()
				-- Create tube (Translates and rotates to form sides of tube)
				:translate(0.5, 0, -0.5)
				:rotate(0, rot * 90)

				-- Overlap tubes
				:translate(turn * -0.5, axis * 0.5 - turn * 0.5, axis * 0.5 - turn)
				-- Rotate horizontal tubes
				:rotate(axis * 90, 0, turn * 90)
				-- Uniform transform entire outline (This is done since the outline would currently be inside the floor)
				:translate(0, 0.5)

			outline:newSprite(axis .. rot)
				:texture(blank)
				:size(1, 1)
				:matrix(lineMat)
				:renderType("LINES")
				:color(color)
		end
	end

	local text = outline:newPart("text", "Camera")
	local pvt = text:newPart("pvt"):matrix(mat)
	pvt:newText("icon")
		:pos(0, -0.25, 0)
		:scale(1 / 16)
		:alignment("CENTER")
		:text(icon)
		:light(15)
	pvt:newText("tooltip")
		:pos(-0.75, 0, 0)
		:scale(1 / 32)
		:background(true)
		:light(15)

	return outline
end

local outlines = {
	hover = newOutline(vec(1, 1, 1, 0.4), ":skull_4:"),
	error = newOutline(vec(1, 0, 0, 0.4), "§4✖"),
}

---@param block BlockState?
---@param entity Entity?
---@return boolean isHovering
local function getHovering(block, entity)
	local pos =
		block and block:getPos() + 0.5 or
		entity and entity:getPos()

	if not pos then return false end

	local scr = vectors.toCameraSpace(pos)
	return (scr.xy):length() < 0.5
end

local viewer = client.getViewer()

local textContextBlacklist = {
	FIRST_PERSON_LEFT_HAND = true,
	FIRST_PERSON_RIGHT_HAND = true
}

---@type ModelPart
local outline
function events.skull_render(_, block, item, entity, context)
	local self = get(block or item)
	if not self then return end

	if outline then outline:visible(false) end
	outline = nil

	local priv = self[1]
	if priv.error then
		outline = outlines.error

		outline.text.pvt:getTask("tooltip") --[[@as TextTask]]
			:visible(not textContextBlacklist[context] and getHovering(block, entity))
			:text(priv.error or nil)
	elseif block and (get(viewer:getHeldItem()) or get(viewer:getHeldItem(true))) then
		outline = getHovering(block, entity) and outlines.hover
	end

	if not outline then return end
	outline:visible(true)
end

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkulls ♡˚
--==============================================================================================================================

---@class FOXSkulls
---@field block_init FOXSkullAPI.Events.block
---@field item_init FOXSkullAPI.Events.item
---@field block_deinit FOXSkullAPI.Events.block
---@field item_deinit FOXSkullAPI.Events.item
---@field protected [FOXSkull.key.uuid] FOXSkull.any?
---@field protected [BlockState] FOXSkull.block?
---@field protected [ItemStack] FOXSkull.item?
---@field protected [Vector3] FOXSkull.block?
local skulls = setmetatable({}, {
	__index = function(_, k) return get(k) end,
	__newindex = function(_, k, v)
		if not skullEvents[k] then
			error("Failed to set key " .. k, 2)
		elseif type(v) ~= "function" then
			error("Function expected, got " .. type(v), 2)
		end

		table.insert(skullEvents[k], v)
	end,
	__type = "FOXSkullAPI",
	__version = "1.0.0",
	__branch = "dev-flat",
})

return skulls

--#ENDREGION
