--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's SkullAPI v1.0.0-dev

Github: https://github.com/Bitslayn/FOXSkullAPI
Docs: https://github.com/Bitslayn/FOXSkullAPI/wiki
]]

-- DO NOT TOUCH THESE VALUES

local __brand, __ver, __branch = "FOXSkullAPI", "1.0.0", "dev"
local __sign = string.format("%s+%s-%s", __brand, __ver, __branch)

--==============================================================================================================================
--#REGION ˚♡ Utilities ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Assert ♡˚
------------------------------------------------------------------------------------------------

---Raises an error if the value of its argument v is false (i.e., `nil` or `false`); otherwise, returns all its arguments. In case of error, `message` is the error object; when absent, it defaults to `"assertion failed!"`
---@generic T
---@param v? T
---@param message? any
---@param level? integer
---@return T v
function assert(v, message, level)
	return v or error(message or "Assertion failed!", (level or 1) + 1)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Sound Listener ♡˚
------------------------------------------------------------------------------------------------

--#REGION Database

---@type {[string]: Sound}
local stableSounds = {}
---@type {[Sound]: string}
local soundNames = {}
---@type {[string]: string|integer[]}
local soundData = {}

for name, data in pairs(avatar:getNBT().sounds) do
	soundNames[sounds[name]] = name
	soundData[name] = data
end

--#ENDREGION
--#REGION Listener

local sound_m = figuraMetatables.SoundAPI
local sound_i = sound_m.__index

---@class SoundAPI
local soundProxy = {}

function soundProxy:newSound(name, data)
	self = sound_i(self, "newSound")(self, name, data)
	soundNames[sounds[name]] = name
	soundData[name] = data
	return self
end

function sound_m.__index(s, k)
	local returned = sound_i(s, k)
	if type(returned) == "Sound" then
		soundNames[returned] = k
		return returned
	end
	return soundProxy[k] or returned
end

function events.resource_reload()
	for name in pairs(stableSounds) do
		if soundData[name] then
			-- Refresh sound references on reload

			sounds:newSound(name, soundData[name])
			stableSounds[name] = sound_i(sounds, name)
		else
			-- Dereferences sounds which cannot be reregistered for whatever reason (Errors may occur without this here)

			stableSounds[name] = nil
			soundData[name] = nil
		end
	end
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Texture Allocator ♡˚
------------------------------------------------------------------------------------------------

---@class FOXSkull.AllocatedTexture
---@field name string
---@field bytes string|integer[]
---@field count integer
---@field sources {[table]: any}
---@field slot integer
---@field texture Texture

---@type table<string, string>
local textureAliases = {}

local textureLimitCount = 64
local texturesUsedCount = 0

---@type string[]
local textureQueueMap = {}
---@type table<string, FOXSkull.AllocatedTexture>
local textureQueue = {}
---@type string[]
local texturesUsedMap = {}
---@type table<string, FOXSkull.AllocatedTexture>
local texturesUsed = {}

local function queueTick()
	if not textureQueueMap[1] or texturesUsedCount == textureLimitCount then return end

	local name = textureQueueMap[1]
	local self = textureQueue[name]
	table.remove(textureQueueMap, 1)
	if not self then return end

	---@type integer
	local slot
	for i = 1, textureLimitCount do
		if not texturesUsedMap[i] then
			slot = i
			texturesUsedCount = texturesUsedCount + 1
			break
		end
	end

	texturesUsedMap[slot] = name
	texturesUsed[name] = self
	textureQueue[name] = nil

	self.slot = slot
	self.texture = textures:read("_FOXSkullTex-" .. slot, self.bytes)
	textureAliases["_FOXSkullTex-" .. slot] = name

	for _, source in pairs(self.sources) do
		source.tbl[source.key] = self.texture
	end
	self.sources = {}
end

---Queues a texture to be allocated as soon as an opening becomes available
---@param name string
---@param bytes string|integer[]
---@param tbl table
---@param key any
local function queueTexture(name, bytes, tbl, key)
	local isAllocated = texturesUsed[name]

	if not (textureQueue[name] or isAllocated) then
		textureQueue[name] = {
			name = name,
			bytes = bytes,
			count = 0,
			sources = {},
			slot = nil,
			texture = nil,
		}
		table.insert(textureQueueMap, name)
	end

	local self = textureQueue[name] or texturesUsed[name]
	self.count = self.count + 1
	if isAllocated then
		tbl[key] = self.texture
	else
		table.insert(self.sources, { tbl = tbl, key = key })
	end
end

---Searches for textures contained in this skull's vars and removes them
---@param vars table
local function removeTextures(vars)
	local function search(curr)
		---@type FOXSkull.AllocatedTexture
		local self

		local t = type(curr)
		if t == "table" then
			for _, value in pairs(curr) do
				search(value)
			end
		elseif t == "Texture" then
			self = texturesUsed[textureAliases[curr:getName()]]
		elseif t == "UnallocatedTexture" then
			self = textureQueue[curr.name]
		end

		if not self then return end
		self.count = self.count - 1

		if self.count ~= 0 then return end

		if self.slot then
			texturesUsed[self.name] = nil
			texturesUsedMap[self.slot] = nil

			texturesUsedCount = texturesUsedCount - 1
		else
			textureQueue[self.name] = nil
		end
	end
	search(vars)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Split Strings ♡˚
------------------------------------------------------------------------------------------------

---Splits the given string at `i` and returns two substrings
---@param s string
---@param i integer
---@return string, string
local function split(s, i)
	return s:sub(1, i), s:sub(i + 1)
end

---Splits the given string at every `i` and returns the substrings
---@param s string
---@param i integer
---@return string ...
local function gsplit(s, i)
	local t = {}
	local a, b = s, s
	repeat
		b, a = split(a, i)
		table.insert(t, b)
	until a == ""
	return table.unpack(t)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Base64 ♡˚
------------------------------------------------------------------------------------------------

local base64 = {}

local function isBase64(str)
	return type(str) == "string" and #str % 4 == 0 and str:match("^[A-Za-z0-9+/]+=*$") == str
end

--#REGION Encode

---Converts the given string to base64
---@param value string
---@return string
function base64.encode(value)
	local buffer = data:createBuffer()
	buffer:writeByteArray(value)
	buffer:setPosition(0)
	local encoded = buffer:readBase64()
	buffer:close()
	return encoded
end

--#ENDREGION
--#REGION Decode

---Converts from base64 to a readable string
---@param value string
---@return string
function base64.decode(value)
	local buffer = data:createBuffer()
	buffer:writeBase64(value)
	buffer:setPosition(0)
	local decoded = buffer:readByteArray()
	buffer:close()
	return decoded
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > JSON ♡˚
------------------------------------------------------------------------------------------------

---@alias FOXSkullAPI.JSON.Vector number[]
---@alias FOXSkullAPI.JSON.Matrix number[][]
---@alias FOXSkullAPI.JSON.Entity string
---@alias FOXSkullAPI.JSON.Block {state: string, pos: [number, number, number]}
---@alias FOXSkullAPI.JSON.Item {stack: string, count: integer, damage: integer}
---@alias FOXSkullAPI.JSON.Part string[]
---@alias FOXSkullAPI.JSON.Sound {name: string, bytes: string|integer[]}
---@alias FOXSkullAPI.JSON.Texture {name: string, bytes: string|integer[]}
---@alias FOXSkullAPI.JSON.Fragment {name: string, uuid: string, chunk: string, len: integer, pos: integer}

local json = {}

---Returns if the given string is a json string
---@param str string
---@return boolean
local function isJson(str)
	local success, result = pcall(parseJson, str)
	return success and str ~= result
end

--#REGION Encode

---Converts the Figura type into a value
---@type {[string]: fun(v: any): type: string, value: any}
local encodeTypes = {
	---@param v Vector2
	Vector2 = function(v)
		return "Vector", { v:unpack() }
	end,
	---@param v Vector3
	Vector3 = function(v)
		return "Vector", { v:unpack() }
	end,
	---@param v Vector4
	Vector4 = function(v)
		return "Vector", { v:unpack() }
	end,


	---@param v Matrix2
	Matrix2 = function(v)
		local t = {}
		for i = 1, #v do
			t[i] = { v[i]:unpack() }
		end
		return "Matrix", t
	end,
	---@param v Matrix3
	Matrix3 = function(v)
		local t = {}
		for i = 1, #v do
			t[i] = { v[i]:unpack() }
		end
		return "Matrix", t
	end,
	---@param v Matrix4
	Matrix4 = function(v)
		local t = {}
		for i = 1, #v do
			t[i] = { v[i]:unpack() }
		end
		return "Matrix", t
	end,


	---@param v Player
	PlayerAPI = function(v)
		return "Entity", v:getUUID()
	end,
	---@param v Entity
	EntityAPI = function(v)
		return "Entity", v:getUUID()
	end,
	---@param v LivingEntity
	LivingEntityAPI = function(v)
		return "Entity", v:getUUID()
	end,
	NullEntity = function()
		return "Entity", avatar:getUUID()
	end,


	---@param v BlockState
	BlockState = function(v)
		return "Block", { state = v:toStateString(), pos = { v:getPos():unpack() } }
	end,
	---@param v ItemStack
	ItemStack = function(v)
		return "Item", { stack = v:toStackString(), count = v:getCount(), damage = v:getDamage() }
	end,


	---@param v ModelPart
	ModelPart = function(v)
		local p = {}
		while v:getParent() do
			table.insert(p, 1, v:getName())
			v = v:getParent()
		end
		return "Part", p
	end,


	---@param v Sound
	Sound = function(v)
		local n = soundNames[v]
		assert(n)
		return "Sound", { name = n, bytes = soundData[n] }
	end,
	---@param v Texture
	Texture = function(v)
		return "Texture", { name = v:getName(), bytes = v:save() }
	end,
}

---Converts the given table into a JSON string, supporting Figura's non-primitive types
---@param value any
---@return string
function json.encode(value)
	local function pack(curr)
		local t = type(curr)
		local packed = {}

		if encodeTypes[t] then
			local name, val = encodeTypes[t](curr)
			packed = { type = name, value = val }
		elseif t == "table" then
			for k, v in pairs(curr) do
				packed[k] = pack(v)
			end
		else
			packed = curr
		end

		return packed
	end

	return toJson(pack(value))
end

--#ENDREGION
--#REGION Decode

---Converts json numbers into Lua numbers
---@type {[string]: number}
local decodeStrings = {
	Infinity = math.huge,
	["-Infinity"] = -math.huge,
	NaN = math.huge - math.huge,
}

---Converts a vector table into a Figura vector
---@param v number[]
---@return Vector.any
local function decodeVector(v)
	for i = 1, #v do
		v[i] = decodeStrings[v[i]] or v[i]
	end
	return vec(table.unpack(v))
end

---Converts the value into a Figura type
---@type {[string]: fun(v: any): any}
local decodeTypes = {
	---@param v number[]
	---@return Vector.any
	Vector = function(v)
		return decodeVector(v)
	end,
	---@param v number[][]
	---@return Matrix.any
	Matrix = function(v)
		local m = matrices["mat" .. #v]() --[[@as Matrix.any]]
		for i = 1, #v do
			m[i] = decodeVector(v[i])
		end
		return m
	end,
	---@param v string
	---@return Entity
	Entity = function(v)
		return world.getEntity(v)
	end,
	---@param v table<string, any>
	---@return BlockState
	Block = function(v)
		return world.newBlock(v.state, v.pos and vectors.vec3(table.unpack(v.pos)))
	end,
	---@param v table<string, any>
	---@return ItemStack
	Item = function(v)
		return world.newItem(v.stack, v.count, v.damage)
	end,
	---@param v string[]
	---@return ModelPart
	Part = function(v)
		local p = models
		for _, chld in ipairs(v) do
			p = p[chld]
		end
		return p
	end,
	---@param v table<string, any>
	---@return Sound
	Sound = function(v)
		sounds:newSound(v.name, v.bytes)
		return sounds[v.name]
	end,
	---@param v table<string, any>
	---@return FOXSkullAPI.JSON.Texture
	Texture = function(v)
		return setmetatable(v, { __type = "UnallocatedTexture" })
	end,
	---@param v table
	---@return FOXSkullAPI.JSON.Fragment
	Fragment = function(v)
		return setmetatable(v, { __type = "Fragment" })
	end,
}

---Decodes the given JSON string into a table, supporting Figura's non-primitive types
---@param str string
---@return any
function json.decode(str)
	local tbl = parseJson(str)

	local function unpack(curr)
		-- Convert strings into numbers

		if type(curr) == "string" then
			curr = decodeStrings[curr] or curr
		end

		-- Convert Figura types

		if type(curr) ~= "table" then return curr end
		local unpacked = {}

		if curr.type and decodeTypes[curr.type] then
			unpacked = decodeTypes[curr.type](curr.value)
		else
			for k, v in pairs(curr) do
				unpacked[k] = unpack(v)

				if type(unpacked[k]) == "Fragment" then
					json.defragment(unpacked[k], unpacked, k)
				elseif type(unpacked[k]) == "UnallocatedTexture" then
					queueTexture(unpacked[k].name, unpacked[k].bytes, unpacked, k)
				end
			end
		end

		return unpacked
	end

	return unpack(tbl)
end

--#ENDREGION
--#REGION Fragment

---@type {[string]: table}
local fragments = {}

---Fragments the given value, returning each fragment at the specified byte size
---
---Byte count must be a multiple of 4
---@param name string
---@param value any
---@param bytes number
---@return {type: string, value: FOXSkullAPI.JSON.Fragment}[]
function json.fragment(name, value, bytes)
	assert(type(name) == "string", "String expected for param [1], got " .. type(name), 2)
	assert(type(bytes) == "number", "Number expected for param [3], got " .. type(bytes), 2)
	assert(bytes % 4 == 0, "Byte count must be a multiple of 4!", 2)

	local uuid = client.intUUIDToString(client.generateUUID()):match("^(.-)%-")
	local chunks = { gsplit(json.encode(value), bytes * 0.75) }

	local out = {}
	for i, chunk in ipairs(chunks) do
		out[i] = { type = "Fragment", value = { name = name, uuid = uuid, chunk = chunk, len = #chunks, pos = i } }
	end

	return out
end

---Internal function which registers a fragment part to be defragmented
---
---This should never be called manually
---@param frag FOXSkullAPI.JSON.Fragment
---@param tbl table
---@param key any
function json.defragment(frag, tbl, key)
	if not fragments[frag.uuid] then
		fragments[frag.uuid] = { chunks = {}, sources = {}, count = 0 }
	end

	local self = fragments[frag.uuid]
	table.insert(self.sources, { tbl = tbl, key = key })

	if not self.chunks[frag.pos] then
		self.count = self.count + 1
		self.chunks[frag.pos] = frag.chunk
	end

	if self.count < frag.len then return end

	local defrag = table.concat(self.chunks)
	for _, source in pairs(self.sources) do
		source.tbl[source.key] = json.decode(defrag)
		if type(source.tbl[source.key]) == "UnallocatedTexture" then
			queueTexture(source.tbl[source.key].name, source.tbl[source.key].bytes, source.tbl, source.key)
		end
	end
	self.sources = {}
end

--#ENDREGION
--#REGION Format

---Converts json numbers into Lua strings
---@type {[string]: string}
local formatStrings = {
	nan = "NaN",
}

---Converts the Figura type into a formatted string
---@type {[string]: fun(v: any): name: string, type: string?}
local formatTypes = {
	---@param v Vector2
	Vector2 = function(v)
		return tostring(v)
	end,
	---@param v Vector3
	Vector3 = function(v)
		return tostring(v)
	end,
	---@param v Vector4
	Vector4 = function(v)
		return tostring(v)
	end,


	---@param v Matrix2
	Matrix2 = function(v)
		local s = tostring(v)
			:sub(2)
			:gsub(string.char(9), "  ")
		return s
	end,
	---@param v Matrix3
	Matrix3 = function(v)
		local s = tostring(v)
			:sub(2)
			:gsub(string.char(9), "  ")
		return s
	end,
	---@param v Matrix4
	Matrix4 = function(v)
		local s = tostring(v)
			:sub(2)
			:gsub(string.char(9), "  ")
		return s
	end,


	---@param v Player
	PlayerAPI = function(v)
		return v:getName(), "Player"
	end,
	---@param v Entity
	EntityAPI = function(v)
		return v:getName(), "Entity"
	end,
	---@param v LivingEntity
	LivingEntityAPI = function(v)
		return v:getName(), "LivingEntity"
	end,


	---@param v BlockState
	BlockState = function(v)
		return v.id, type(v)
	end,
	---@param v ItemStack
	ItemStack = function(v)
		return v.id .. " x" .. v:getCount(), type(v)
	end,


	---@param v ModelPart
	ModelPart = function(v)
		return v:getName(), type(v)
	end,


	---@param v Sound
	Sound = function(v)
		return soundNames[v], "Sound"
	end,
	---@param v Texture
	Texture = function(v)
		return textureAliases[v:getName()] .. string.format(" (%sx%s)", v:getDimensions():unpack()), "Texture"
	end,
	---@param v FOXSkullAPI.JSON.Texture
	UnallocatedTexture = function(v)
		return v.name, "UnallocatedTexture"
	end,

	---@param v FOXSkullAPI.JSON.Fragment
	Fragment = function(v)
		return v.name .. string.format(" (%s/%s)", v.pos, v.len), "Fragment"
	end,
}

---@type table<string, string>
local formatCache = {}

---Formats the given table and returns a prettified string
---@param tbl table
---@return string?
function json.format(tbl)
	local key = json.encode(tbl)
	if formatCache[key] then return formatCache[key] end

	local fig, i = {}, 0

	---@param ... any
	---@return string
	local function push(...)
		i = i + 1
		local x = string.format("%x", i)
		fig[x] = (({ ... })[3] and "%s%s (%s)r" or "%s%sr"):format(...)
		return "${" .. x .. "}"
	end

	---@param curr any
	---@return any
	local function rawType(curr)
		local t = type(curr)
		local converted = {}

		if formatTypes[t] then
			local name, type = formatTypes[t](curr)
			converted = push("e", name, type)
		elseif t == "table" then
			for k, v in pairs(curr) do
				converted[k] = rawType(v)
			end
		elseif t == "number" then
			converted = push("b", formatStrings[tostring(curr)] or curr)
		elseif t == "boolean" then
			converted = push(curr and "a" or "c", tostring(curr))
		else
			converted = curr
		end

		return converted
	end

	local str = toJson(rawType(tbl))
	if str == "{}" then return end

	local indent = 0
	local isString = false
	local isFigura = false

	---Pattern matching only the chars looked at
	local pattern = "[\"'{}%[%],:\n]"

	---@type {[string]: fun(s: string): string?}
	local chars = {
		['"'] = function() isString = not isString end,
		["'"] = function() isString = not isString end,

		[""] = function() isFigura = not isFigura end,

		["{"] = function(s)
			if isString or isFigura then return s end

			indent = indent + 1
			return s .. "\n" .. string.rep("  ", indent)
		end,
		["["] = function(s)
			if isString or isFigura then return s end

			indent = indent + 1
			return s .. "\n" .. string.rep("  ", indent)
		end,
		["}"] = function(s)
			if isString or isFigura then return s end

			indent = indent - 1
			return "\n" .. string.rep("  ", indent) .. s
		end,
		["]"] = function(s)
			if isString or isFigura then return s end

			indent = indent - 1
			return "\n" .. string.rep("  ", indent) .. s
		end,

		[","] = function(s)
			if isString or isFigura then return s end

			return s .. "\n" .. string.rep("  ", indent)
		end,
		[":"] = function(s)
			if isString or isFigura then return s end

			return s .. " "
		end,

		["\n"] = function(s)
			return s .. string.rep("  ", indent)
		end,
	}

	str = str
		:gsub("", "")                                                 -- Remove all user-defined sub chars
		:gsub('"%${(%x+)}"', fig)                                      -- Add formatted Figura types to json string
		:gsub(pattern, function(s) return chars[s] and chars[s](s) or s end) -- Format json string
		:gsub("", "§")                                                -- Replace sub chars with legacy formatting code

	formatCache[key] = str
	return str
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Item Generator ♡˚
------------------------------------------------------------------------------------------------

--#REGION Helper

---Packs the given strings into a table of json strings
---@param multiline boolean
---@param index string
---@param ... string|string[]
---@return string|string[]
local function pack(multiline, index, ...)
	local lines = {}

	-- Build line sections

	for k, v in pairs({ ... }) do
		if type(v) == "table" then
			local sections = {}
			for k2, v2 in pairs(v) do
				sections[k2] = isJson(v2) and parseJson(v2) or { [index] = v2 }
			end
			lines[k] = sections
		else
			lines[k] = isJson(v) and parseJson(v) or { [index] = v }
		end
	end

	-- Format into valid NBT

	local nbt
	if multiline then
		nbt = {}
		for k, v in pairs(lines) do nbt[k] = toJson(v) end
	else
		nbt = toJson(lines)
	end
	return nbt
end

--#ENDREGION
--#REGION Generator

---@class FOXSkull.generatedItemStack
---@field item Minecraft.itemID
---@field data table
local itemGenerator = {
	---@param self FOXSkull.generatedItemStack
	---@package
	__tostring = function(self)
		local replace = {
			uuid = "[I;" .. toJson({ client.uuidToIntArray(self.uuid) }):sub(2), -- Combines `[I;` with the substring of `int,int,int,int]`
		}
		return self.item .. toJson(self.data):gsub('"%${(%a+)}"', replace)
	end,
}
---@package
itemGenerator.__index = itemGenerator

---Automagically creates a new item object, or returns the current one
---@generic self
---@param self self
---@return self
local function newItem(self)
	if self ~= itemGenerator then return self end
	return setmetatable({
		item = "minecraft:air",
		data = {
			display = {},
			SkullOwner = { Id = "${uuid}" },
		},
	}, itemGenerator)
end

--#ENDREGION
--#REGION Methods

---Sets this item's ID
---@param item Minecraft.itemID?
---@return self
function itemGenerator:setItem(item)
	self = newItem(self)
	self.item = item or "minecraft:air"
	return self
end

---Sets the name of this item
---
---Can take multiple strings, and takes json strings. Group together strings to put them on the same line
---@param ... string|string[]?
---@return self
function itemGenerator:setName(...)
	self = newItem(self)
	self.data.display.Name = ... and pack(false, "text", ...)
	return self
end

---Sets the lore of this item
---
---Can take multiple strings, and takes json strings. Group together strings to put them on the same line
---@param ... string|string[]?
---@return self
function itemGenerator:setLore(...)
	self = newItem(self)
	self.data.display.Lore = ... and pack(true, "text", ...)
	return self
end

---Sets the skull owner UUID of this item, if it is a player skull
---@param uuid string
---@return self
function itemGenerator:setUUID(uuid)
	self = newItem(self)
	self.uuid = uuid
	return self
end

---Sets the texture fields to the provided strings
---
---If no strings are provided, removes all textures on this item
---@param signature string
---@param ... string
---@return self
function itemGenerator:setTextures(signature, ...)
	local injest = { ... }
	for k, v in ipairs(injest) do
		injest[k] = not isBase64(v) and base64.encode(v) or v
	end

	self = newItem(self)
	local owner = self.data.SkullOwner
	owner.Properties = {}
	owner.Properties.textures = ... and parseJson(pack(false, "Value", table.unpack(injest)) --[[@as string]])
	if signature then
		for _, tex in pairs(owner.Properties.textures) do
			tex.Signature = signature
		end
	end
	return self
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > ModelPart Handler ♡˚
------------------------------------------------------------------------------------------------

---Copies the tasks from the source model to the destination model
---
---This is a backport of a built-in 0.1.6 feature
---@param source ModelPart
---@param dest ModelPart
local function copyTasks(source, dest)
	for _, task in pairs(source:getTask()) do
		dest:addTask(task)
	end
end

---Copies a model and turns it into a skull model
---@param model ModelPart?
---@return ModelPart?
local function copyModel(model)
	if type(model) ~= "ModelPart" then return end

	local hasTasks = next(model:getTask())

	local copy = model:copy(model:getName())
		:parentType("Skull")
		:visible(false)
		:moveTo(models)

	if hasTasks and not next(copy:getTask()) then
		copyTasks(model, copy)
	end

	return copy
end

---Replaces the model of the provided table with a new model, removing the old one
---@param models FOXSkull.models.any
---@param context FOXSkull.context.any|FOXSkull.context.any[]?
---@param model any?
---@param copy boolean?
local function replaceModel(models, context, model, copy)
	context = not context and { "OTHER" } or type(context) == "table" and context or { context }
	copy = copy == nil and true or copy

	local function setModel(ctx, mdp)
		assert(type(mdp) == "ModelPart", "ModelPart expected for param [1], got " .. type(mdp), 4)

		ctx = ctx and string.upper(ctx) or "OTHER"

		if models[ctx] then
			models[ctx]:remove()
		end

		models[ctx] = copy and copyModel(mdp) or mdp
	end

	local meta = getmetatable(model)

	if meta and type(meta["FOXSkull$model"]) == "string" then
		if meta["FOXSkull$contexts"] then
			for ctx, key in pairs(meta["FOXSkull$contexts"]) do
				setModel(ctx, model[meta["FOXSkull$model"]][key])
			end
		else
			for ctx, mdp in pairs(model[meta["FOXSkull$model"]]) do
				setModel(ctx, mdp)
			end
		end
	else
		for _, ctx in pairs(context) do
			setModel(ctx, model[ctx] or model)
		end
	end
end

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkull ♡˚
--==============================================================================================================================

local viewer = world.getPlayers()[client.getViewer():getName()]

---@class FOXSkull
local skull = {}

---@alias FOXSkull.models.any {[FOXSkull.context.any]: ModelPart}

---Internal variables not to be accessed outside of developing FOXSkullAPI!
---@class FOXSkull.private.any
---@field models FOXSkull.models.any
---@field timestamp number
---@field visible boolean?
---@field uuid string
---@field isErrored boolean?
---@field tooltip string?
---@field tooltipOffset Vector3?
---@field hasVars boolean?
---@field generatedItem FOXSkull.generatedItemStack
---@field vars table

---@alias FOXSkull.context.block
---| "BLOCK"                   Placed as a block
---| "OTHER"                   Some other context
---@alias FOXSkull.context.item
---| "HEAD"                    Worn on head
---| "FIRST_PERSON_RIGHT_HAND" Held in right hand in first person
---| "FIRST_PERSON_LEFT_HAND"  Held in left hand in first person
---| "THIRD_PERSON_RIGHT_HAND" Held in right hand in third person or to viewers
---| "THIRD_PERSON_LEFT_HAND"  Held in left hand in third person or to viewers
---| "GROUND"                  Dropped on the ground
---| "FIXED"                   Held in item frame
---| "GUI"	                   Stored in container or inventory
---| "OTHER"                   Some other context. Used for ITEM_ENTITY, ITEM_FRAME, and GUI on 0.1.5
---@alias FOXSkull.context.any FOXSkull.context.block|FOXSkull.context.item

local legacyContexts = {
	RIGHT_HAND = "THIRD_PERSON_RIGHT_HAND",
	LEFT_HAND = "THIRD_PERSON_LEFT_HAND",
}

---@alias FOXSkull.render.block fun(delta: number, self: FOXSkull.block, block: BlockState)
---@alias FOXSkull.render.item fun(delta: number, self: FOXSkull.item, item: ItemStack)
---@alias FOXSkull.render.any fun(delta: number, self: FOXSkull.any)
---@alias FOXSkull.tick.block fun(self: FOXSkull.block, block: BlockState)
---@alias FOXSkull.tick.item fun(self: FOXSkull.item, item: ItemStack)
---@alias FOXSkull.tick.any fun(self: FOXSkull.any)
---@alias FOXSkull.onPunch.block fun(self: FOXSkull.block, puncher: Entity)
---@alias FOXSkull.onPunch.item fun(self: FOXSkull.item, puncher: Entity)
---@alias FOXSkull.onPunch.any fun(self: FOXSkull.any, puncher: Entity)

---Represents any skull, block or item, that's rendered
---@class FOXSkull.any
---@field context FOXSkull.context.any
---@field render FOXSkull.render.any?
---@field tick FOXSkull.tick.any?
---@field onPunch FOXSkull.onPunch.any?
---@field package [1] FOXSkull.private.any
---@field package __index FOXSkull.any
local anyClass = {}
---Represents a skull placed in loaded chunks
---@class FOXSkull.block: FOXSkull.any
---@field block BlockState
---@field context FOXSkull.context.block
---@field render FOXSkull.render.block?
---@field tick FOXSkull.tick.block?
---@field onPunch FOXSkull.onPunch.block?
local blockClass = anyClass
---Represents a unique skull item being rendered
---@class FOXSkull.item: FOXSkull.any
---@field item ItemStack
---@field entity Entity
---@field context FOXSkull.context.item
---@field render FOXSkull.render.item?
---@field tick FOXSkull.tick.item?
---@field onPunch FOXSkull.onPunch.item?
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

--#REGION Blocks

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
	assert(block, "Failed to run function on skull of incorrect type", 2)

	distance = distance or 1
	invert = invert and -1 or 1

	assert(type(distance) == "number", "Number expected for param [1], got " .. type(distance))
	assert(type(invert) == "number", "Number expected for param [2], got " .. type(invert))

	local facing = block.properties.facing
	local pos = block:getPos() - (dirs[facing] or dirs.floor) * invert * distance
	return world.getBlockState(pos)
end

---Gets the visual center position of this skull in the world
---@return Vector3
---@nodiscard
function blockClass:getCenterPos()
	local block = self.block
	assert(block, "Failed to run function on skull of incorrect type", 2)

	local shape = block:getOutlineShape()[1]
	local center = math.lerp(shape[1], shape[2], 0.5) + block:getPos()
	return center
end

---Gets the direction this skull is facing
---@return Vector3
---@nodiscard
function blockClass:getDir()
	local block = self.block
	assert(block, "Failed to run function on skull of incorrect type", 2)

	local rot = tonumber(block.properties.rotation)
	if rot then
		local yaw = math.rad(rot * -22.5 - 180)
		return vec(math.sin(yaw), 0, math.cos(yaw))
	else
		local facing = block.properties.facing
		return dirs[facing]
	end
end

--#ENDREGION
--#REGION Model

---Sets the model to render for this skull
---@generic self
---@param model ModelPart? The modelpart to copy
---@param context FOXSkull.context.any|FOXSkull.context.any[]? Defaults to "OTHER". Sets which render context this model is for
---@param copy boolean? Defaults to true. If the modelpart should be copied or injested
---@return self
---@overload fun(self: FOXSkull.block, model: any?, context: FOXSkull.context.block|FOXSkull.context.block[]?, copy: boolean?): FOXSkull.block
---@overload fun(self: FOXSkull.item, model: any?, context: FOXSkull.context.item|FOXSkull.context.block[]?, copy: boolean?): FOXSkull.item
---@overload fun(self: FOXSkull.any, model: any?, context: FOXSkull.context.any|FOXSkull.context.block[]?, copy: boolean?): FOXSkull.any
function anyClass:setModel(model, context, copy)
	replaceModel(self[1].models, context, model, copy)
	return self
end

---Sets the model to render for this skull
---@generic self
---@param model ModelPart? The modelpart to copy
---@param context FOXSkull.context.any|FOXSkull.context.any[]? Defaults to "OTHER". Sets which render context this model is for
---@param copy boolean? Defaults to true. If the modelpart should be copied or injested
---@return self
---@overload fun(self: FOXSkull.block, model: any?, context: FOXSkull.context.block|FOXSkull.context.block[]?, copy: boolean?): FOXSkull.block
---@overload fun(self: FOXSkull.item, model: any?, context: FOXSkull.context.item|FOXSkull.context.block[]?, copy: boolean?): FOXSkull.item
---@overload fun(self: FOXSkull.any, model: any?, context: FOXSkull.context.any|FOXSkull.context.block[]?, copy: boolean?): FOXSkull.any
function anyClass:model(model, context, copy)
	replaceModel(self[1].models, context, model, copy)
	return self
end

---Gets the model set to render for this skull
---@param context any
---@return ModelPart
---@overload fun(self: FOXSkull.block, context: FOXSkull.context.block?): ModelPart
---@overload fun(self: FOXSkull.item, context: FOXSkull.context.item?): ModelPart
---@nodiscard
function anyClass:getModel(context)
	context = context and string.upper(context) or "OTHER"
	return self[1].models[context]
end

--#ENDREGION
--#REGION Data

---@param str string
---@return string
local function parseName(str)
	local name = parseJson(str)
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
		if not data then return "Player Head" end
		return data.custom_name and parseName(data.custom_name) or "Player Head" -- Block for 1.21+
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
	assert(self.item, "Failed to run function on skull of incorrect type", 2)

	local tag = self.item.tag
	local lines = tag.display and tag.display.Lore or tag.lore or tag["minecraft:lore"]
	if not lines then return end
	return parseLore(lines)
end

---@param textures table
---@param i integer
---@param j integer
---@param signature string
---@return string
local function parseTextures(textures, i, j, signature)
	local data = ""
	for k = math.max(i, 1), math.min(j, #textures) do
		local texture = textures[k]
		local sig = texture.signature or texture.Signature
		if not signature or sig and sig:find(signature) then
			data = texture and data .. base64.decode(texture.value or texture.Value) or data
		end
	end
	return data
end

---Gets this skull's parsed texture data
---
---If a single integer is given, returns the texture field for that index
---
---If two integers are given, treats them as a range, returning those texture fields concatenated
---
---Concatenates all texture fields if no integers are given
---
---If a signature is provided, all textures without a matching signature will be skipped over
---@generic self
---@param self self
---@param i integer?
---@param j integer?
---@param signature string?
---@return string
---@nodiscard
function anyClass:getData(i, j, signature)
	i, j = i or 1, j or i or math.huge

	local block = self --[[@as FOXSkull.block]].block
	local item = self --[[@as FOXSkull.item]].item
	local nbt = block and block:getEntityData() or item and item.tag
	if not nbt then return "" end

	local textures = nbt.SkullOwner and nbt.SkullOwner.Properties and nbt.SkullOwner.Properties.textures or -- < 1.21.9
		nbt.profile and nbt.profile.properties                                                           -- 1.21.9+

	return textures and parseTextures(textures, i, j, signature) or ""
end

--#ENDREGION
--#REGION Visibility

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

--#ENDREGION
--#REGION Functions

---Sets the function to run when this skull renders
---@overload fun(self: FOXSkull.block, func: FOXSkull.render.block): FOXSkull.block
---@overload fun(self: FOXSkull.item, func: FOXSkull.render.item): FOXSkull.item
function anyClass:setRender(func)
	self.render = func
	return self --[[@as FOXSkull.block|FOXSkull.item]]
end

---Sets the function to run when this skull ticks
---@overload fun(self: FOXSkull.block, func: FOXSkull.tick.block): FOXSkull.block
---@overload fun(self: FOXSkull.item, func: FOXSkull.tick.item): FOXSkull.item
function anyClass:setTick(func)
	self.tick = func
	return self --[[@as FOXSkull.block|FOXSkull.item]]
end

---Sets a function to run when this skull is punched
---@overload fun(self: FOXSkull.block, func: FOXSkull.onPunch.block): FOXSkull.block
---@overload fun(self: FOXSkull.item, func: FOXSkull.onPunch.item): FOXSkull.item
function anyClass:setOnPunch(func)
	self.onPunch = func
	return self --[[@as FOXSkull.block|FOXSkull.item]]
end

--#ENDREGION
--#REGION UUID

---Gets this skull's uuid
---@return string
---@nodiscard
function anyClass:getUUID()
	return self[1].uuid
end

--#ENDREGION
--#REGION Vars

---Sets a variable on this skull
---
---Variables can be accessed with <skull>:getVariable() and is stored into the skull's texture data when given with <skull>:getItemStack()
---@generic self
---@param self self
---@param key any
---@param value any
---@return self
function anyClass:variable(key, value)
	self[1].vars[key] = value
	return self
end

---Sets a variable on this skull
---
---Variables can be accessed with <skull>:getVariable() and is stored into the skull's texture data when given with <skull>:getItemStack()
---@generic self
---@param self self
---@param key any
---@param value any
---@return self
function anyClass:setVariable(key, value)
	self[1].vars[key] = value
	return self
end

---Gets a variable stored on this skull
---
---Returns an unlocked table of variables stored if no key is provided
---@param key any?
---@return unknown
function anyClass:getVariable(key)
	return not key and self[1].vars or self[1].vars[key]
end

--#ENDREGION
--#REGION Item

---Gets this skull as an ItemStack
---
---All variables set to this skull will be stored in this ItemStack and is placable
---
---Any keys or values that aren't json compatible will be nullified when converting a skull to an item
---@param count integer?
---@param damage integer?
---@return ItemStack
---@nodiscard
function anyClass:getItemStack(count, damage)
	local priv = self[1]
	-- n * 0.75; where n is the total chunk length after converting to Base64. n must be divisible by 4!

	priv.generatedItem:setTextures(__sign, gsplit(json.encode(priv.vars), 32764 * 0.75))
	return world.newItem(tostring(priv.generatedItem), count, damage)
end

---Returns the first open hotbar slot from the selected slot
---
---If no slot is open then the current selected slot is used
---@return number
local function findOpenSlot()
	local player = world.getPlayers()[avatar:getEntityName()]
	local selectedSlot = player:getNbt().SelectedItemSlot
	local slot = selectedSlot
	repeat
		if host:getSlot(slot).id == "minecraft:air" then break end
		slot = (slot + 1) % 9
	until slot == selectedSlot
	return slot
end

---Gives the host this skull as an item in their hotbar
---
---Only works if this player is in creative. OP is not required
---@generic self
---@param self self
---@param count number?
---@param damage number?
---@return self
function anyClass:giveItem(count, damage)
	local player = world.getPlayers()[avatar:getEntityName()]
	if host:isHost() and player:getGamemode() == "CREATIVE" then
		host:setSlot(findOpenSlot(), self --[[@as FOXSkull.any]]:getItemStack(count, damage))

		sounds["minecraft:entity.item.pickup"]
			:pos(player:getPos())
			:volume(0.5)
			:pitch(2)
			:play()
	end

	return self
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Events ♡˚
------------------------------------------------------------------------------------------------

---@alias FOXSkullAPI.events.block fun(skull: FOXSkull.block, block: BlockState)
---@alias FOXSkullAPI.events.item fun(skull: FOXSkull.item, item: ItemStack)
---@alias FOXSkullAPI.events.any fun(skull: FOXSkull.any)
---@class FOXSkullAPI.Events
local skullEvents = {
	---@type FOXSkullAPI.events.block[]
	block_init = {},
	---@type FOXSkullAPI.events.item[]
	item_init = {},
	---@type FOXSkullAPI.events.any[]
	skull_init = {},
	---@type FOXSkullAPI.events.block[]
	block_deinit = {},
	---@type FOXSkullAPI.events.item[]
	item_deinit = {},
	---@type FOXSkullAPI.events.any[]
	skull_deinit = {},
}

---Catches an internal skull error
---
---Functions the same as a pcall
---@param self FOXSkull.any
---@param f function
---@param ... any
---@return any
local function try(self, f, ...)
	---@type boolean, string
	local success, result = pcall(f, ...)
	if success then return result end

	result = "§c[error] §f" .. avatar:getEntityName() .. "§c : " .. tostring(result)
		:gsub("\9", "  ")
	if not result:find("^[^\n]*FOXSkullAPI[^\n]*") then    -- Truncate strace if FOXSkullAPI isn't at top of traceback
		result = result
			:gsub("[^\n]*\n[^\n]*'pcall'.-$", "  [SkullAPI]: in ?") -- Truncate line above pcall
			:gsub("[^\n]*'pcall'.-$", "  [SkullAPI]: in ?") -- Truncate pcall (edge case)
	end

	local priv = self[1]
	priv.isErrored = not success
	priv.tooltip = result
end

local onMax = avatar:getMaxWorldTickCount() == 2 ^ 31 - 1 and avatar:getMaxRenderCount() == 2 ^ 31 - 1

---@param self FOXSkull.any
---@param state boolean
local function skullInit(self, state)
	-- Converts the type into a skull event string. The state is whether this is an init or deinit event.
	-- FOXSkull.block ORIGINAL => FOXSkull.(block) SUBSTRING => block_init CONCATENATED

	local t = type(self)
	local k1 = t:sub(10, #t) .. (state and "_init" or "_deinit")
	local k2 = state and "skull_init" or "skull_deinit"

	-- Tries to call the appropriate event functions defined by the user

	try(self, function()
		assert(onMax, "FOXPlayerSkull requires max permissions!", 4)

		local this = self --[[@as FOXSkull.block]].block or self --[[@as FOXSkull.item]].item
		---@diagnostic disable-next-line: param-type-mismatch
		for _, func in pairs(skullEvents[k1]) do func(self, this) end
		for _, func in pairs(skullEvents[k2]) do func(self, this) end
	end)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Accessor ♡˚
------------------------------------------------------------------------------------------------

--#REGION Get

---@type fun(key: FOXSkull.key.genericKey, entity: Entity?): FOXSkull.key.internalID
local idSwitch = {
	---@param key FOXSkull.key.uuid
	---@return FOXSkull.key.internalID
	string = function(key) return uuids[key] end,
	---@param key BlockState
	---@return FOXSkull.key.internalID
	BlockState = function(key) return key:getPos():toString() end,
	---@param key ItemStack
	---@param entity Entity
	---@return FOXSkull.key.internalID
	ItemStack = function(key, entity)
		return key:getCount()
			.. (entity and entity:getUUID() or viewer:getUUID())
			.. key:toStackString()
	end,
	---@param key Vector3
	---@return FOXSkull.key.internalID
	Vector3 = function(key) return key:toString() end,
}

---Formats a supported key into an internalID
---
---Returns nil if the key is of an invalid type
---@param key FOXSkull.key.genericKey
---@param entity Entity
---@return FOXSkull.key.internalID?
local function getID(key, entity)
	local switch = idSwitch[type(key)]
	---@diagnostic disable-next-line: param-type-mismatch
	if switch then return switch(key, entity) end
end

---Gets a skull that has been initialized
---
---Returns nil if a skull with the given key does not exist
---@overload fun(key: FOXSkull.key.uuid, entity: Entity?): FOXSkull.any?
---@overload fun(key: BlockState, entity: Entity?): FOXSkull.block?
---@overload fun(key: ItemStack, entity: Entity?): FOXSkull.item?
---@overload fun(key: Vector3, entity: Entity?): FOXSkull.block?
local function get(key, entity)
	return all[getID(key, entity) or key]
end

--#ENDREGION
--#REGION New

---Stores keys which can be changed inside mutable skulls
---@type {[any]: true}
local keyWhitelist = {
	block = true,
	item = true,
	entity = true,
	context = true,
	render = true,
	tick = true,
	onPunch = true,
	[1] = true,
}

---Function that locks a mutable skull's table
---@param s FOXSkull.any
---@param k any
---@param v any
local function lock(s, k, v)
	assert(keyWhitelist[k], 'Cannot assign value to key "' .. k .. '"', 2)
	rawset(s, k, v)
end


local metaAny = { __index = anyClass, __newindex = lock, __type = "FOXSkull.any" }
local metaBlock = { __index = blockClass, __newindex = lock, __type = "FOXSkull.block" }
local metaItem = { __index = itemClass, __newindex = lock, __type = "FOXSkull.item" }

local newSwitch = {
	---@param key BlockState
	---@return FOXSkull.block
	BlockState = function(key)
		local block = key
		local self = setmetatable({}, metaBlock)
		self.block = block
		return self
	end,
	---@param key ItemStack
	---@return FOXSkull.item
	ItemStack = function(key)
		local item = key
		local self = setmetatable({}, metaItem)
		self.item = item:copy()
		return self
	end,
}

---Creates and returns a new skull with the given BlockState or ItemStack
---
---Calls the init event
---
---Returns nil if the key is of an invalid type
---@overload fun(key: BlockState, entity: Entity): FOXSkull.block
---@overload fun(key: ItemStack, entity: Entity): FOXSkull.item
---@overload fun(): FOXSkull.any
local function new(key, entity)
	local switch = newSwitch[type(key)]

	local self = switch and switch(key) or setmetatable({}, metaAny)
	self.entity = entity or self.item and viewer
	self.context = "OTHER"

	---@diagnostic disable-next-line: missing-fields
	self[1] = {
		models = {},
		visible = true,
		uuid = client.intUUIDToString(client.generateUUID()),
		timestamp = switch and client.getSystemTime() or math.huge,
		contexts = {},
		generatedItem = itemGenerator
			:setItem("minecraft:player_head")
			:setUUID(avatar:getUUID()),
	}
	local priv = self[1]

	local data = self:getData(nil, nil, "FOXSkullAPI")
	priv.hasVars = data ~= ""
	priv.vars = priv.hasVars and isJson(data) and try(self, json.decode, data, self) or {}

	if switch then
		local id = getID(key, entity)
		uuids[priv.uuid] = id
		all[id] = self

		skullInit(self, true)
	end

	return self
end

--#ENDREGION
--#REGION Remove

---Removes a skull by its generic key
---
---Calls the deinit event
---@param key FOXSkull.key.genericKey
---@param entity Entity?
local function remove(key, entity)
	local self = get(key, entity)
	if not self then return end

	skullInit(self, false)
	removeTextures(self[1].vars)

	local priv = self[1]
	uuids[priv.uuid] = nil
	all[getID(key, entity) or key] = nil

	for _, model in pairs(priv.models) do
		model:getParent():remove()
	end
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Built-in Models ♡˚
------------------------------------------------------------------------------------------------

local blank = textures:newTexture("blank", 1, 1)

--#REGION Overlays

---@param color Vector3|Vector4?
---@param icon string?
---@param depth number?
---@return ModelPart
local function newWorldOverlay(color, icon, depth)
	local mdp = models:newPart("newWorldOverlay", "Skull")
		:visible(false)

	local outlineMat = matrices.mat4() * (0.5 * (16 / depth))
	outlineMat.c4 = vec(0, (0.25 * (16 / depth)), 0, 1 / depth)
	local iconMat = matrices.mat4() * (1 / (depth * 2))
	iconMat.c4 = vec(0, 0, 0, 1 / depth)
	local tooltipMat = matrices.mat4() * (1 / (depth * 4))
	tooltipMat.c4 = vec(0, 0, 0, 1 / depth)

	local bb = mdp
		:newPart("bb", "Camera")
		:pivot(0, 4)
	local pvt = bb
		:newPart("pvt")
		:matrix(iconMat)
	pvt:newText("icon")
		:pos(0, 7.75)
		:alignment("CENTER")
		:text(icon)
		:light(15)
	local tpvt = bb
		:newPart("tpvt")
	tpvt:newText("fg")
		:matrix(tooltipMat)
		:light(15)
	tpvt:newText("bg")
		:matrix(tooltipMat)
		:light(15)
		:background(true)
		:seeThrough(true)

	local outline = mdp:newPart("outline")

	local i = 0
	for axis = 0, 2 do
		for rot = 0, 3 do
			i = i + 1

			local turn = math.floor(axis / 2)
			local mat = matrices.mat4()
				-- Create tube (Translates and rotates to form sides of tube)
				:translate(0.5, 0, -0.5) -- *Change y to separate tubes*
				:rotate(0, rot * 90)

				-- Overlap tubes
				:translate(turn * -0.5, axis * 0.5 - turn * 0.5, axis * 0.5 - turn)
				-- Rotate horizontal tubes
				:rotate(axis * 90, 0, turn * 90)
				-- Uniform transform entire outline (This is done since the outline would currently be inside the floor)
				:translate(0, 0.5)


			outline:newSprite(i .. "")
				:setTexture(blank)
				:size(1, 1)
				:matrix(mat)
				:renderType("LINES")
				:color(color)
		end
	end

	outline:matrix(outlineMat)

	return mdp
end

local hoverOverlay = newWorldOverlay(vec(1, 1, 1, 0.4), ":skull_4:", 16)
local errorOverlay = newWorldOverlay(vec(1, 0, 0, 0.4), "§4✖", 16)
local silentErrorOverlay = newWorldOverlay(vec(1, 0, 0, 0.4), "", 1)
local infoOverlay = newWorldOverlay(vec(0, 0.5, 1, 0.4), ":info:", 16)
local silentInfoOverlay = newWorldOverlay(vec(0, 0.5, 1, 0.4), "", 1)

--#ENDREGION
--#REGION Vanilla

local vanillaSkull = models:newPart("vanillaSkull", "Skull")
	:visible(false)
vanillaSkull:newSprite("Sprite")
	:setTexture(blank)
local skullItem = vanillaSkull:newItem("Skull")
	:pos(0, 8, 0)
	:item("minecraft:player_head")

pcall(skullItem.item, skullItem, "minecraft:player_head" .. toJson { SkullOwner = avatar:getEntityName() })

--#ENDREGION
--#REGION Invisible

local invisibleSkull = models:newPart("invisibleSkull", "Skull")
	:visible(false)
invisibleSkull:newSprite("Sprite")
	:setTexture(blank)

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Render ♡˚
------------------------------------------------------------------------------------------------

--#REGION Render

local flipFacing = client.compareVersions(client.getVersion(), "1.21") ~= -1

local function getViewerFacingSkull(block)
	local scr = vectors.toCameraSpace(block:getPos() + 0.5)

	if flipFacing then
		scr:mul(-1, 1, -1)
	end

	return scr.xy:length() ^ 2 < scr.z * 1.5 ^ 2
end

local function getViewerSelectingSkull(block, entity)
	return
		entity == viewer and not renderer:isFirstPerson() or
		block and viewer:getTargetedBlock():getPos() == block:getPos() or
		entity and viewer:getTargetedEntity() == entity
end

---@type FOXSkull.models.any
local defaultModels = {}
---@type ModelPart, ModelPart, ModelPart
local currentModel, overlay, tooltip
---@type FOXSkull.any
local selected

---@type FOXSkull.any
local heldSkull

function events.skull_render(delta, block, item, entity, context)
	-- Update vars

	context = legacyContexts[context] or context

	---@type BlockState|ItemStack
	local this = block or item

	---@type FOXSkull.any
	local self = get(this, entity) or new(this, entity)
	local priv = self[1]

	local time = client.getSystemTime()
	priv.timestamp = time

	---@diagnostic disable-next-line: assign-type-mismatch
	self.context = context


	-- Skull is rendering, run its render function

	if self.render and not priv.isErrored then
		try(self, self.render, delta, self, this)
	end


	-- Render this skull's model

	if currentModel then currentModel:visible(false) end
	currentModel = nil

	if priv.isErrored then
		currentModel = vanillaSkull
	elseif priv.models[context] or priv.models.OTHER then
		currentModel = priv.visible and (priv.models[context] or priv.models.OTHER) or invisibleSkull
	else
		currentModel = defaultModels[context] or defaultModels.OTHER
	end

	if currentModel then currentModel:visible(true) end


	-- Render this skull's overlay and tooltip

	if overlay then overlay:visible(false) end
	overlay = nil
	if tooltip then tooltip:visible(false) end
	tooltip = nil

	if not currentModel then return end

	local facingSkull = heldSkull and block and getViewerFacingSkull(block)
	local isSelected = getViewerSelectingSkull(block, entity)

	-- Newer versions have issues with some render types
	local overlayBL = context == "OTHER" or context:find("FIRST_PERSON")

	if priv.isErrored and not overlayBL then
		overlay = facingSkull and errorOverlay or silentErrorOverlay
	elseif priv.hasVars and client.isDebugOverlayEnabled() then
		overlay = facingSkull and infoOverlay or silentInfoOverlay
	elseif facingSkull then
		overlay = hoverOverlay
		priv.tooltip = nil
	end

	if isSelected and overlay then
		tooltip = overlay.bb.tpvt:visible(true)
		tooltip:pos(priv.tooltipOffset)
		tooltip:getTask("fg") --[[@as TextTask]]
			:text(priv.tooltip)
		tooltip:getTask("bg") --[[@as TextTask]]
			:text(priv.tooltip)

		selected = self
	end

	if overlay then overlay:visible(true) end
end

--#ENDREGION
--#REGION Tick

---@type Entity[]
local cachedPunches

---Gets all entities near the viewer
local function getEntities()
	local pos = viewer:getPos()
	return world.getEntities(pos - 8, pos + 8)
end

---Gets the skull being held by the entity, if one is being held
---
---If offhand is nil then both hands are checked. If offhand is a boolean then only one hand is checked
---@param entity Entity.any
---@param offhand boolean|nil
---@return FOXSkull.item?
local function getHeldSkull(entity, offhand)
	if offhand == nil then
		---@diagnostic disable-next-line: param-type-mismatch
		local main = entity:getHeldItem()
		---@diagnostic disable-next-line: param-type-mismatch
		local off = entity:getHeldItem(true)

		return main.id == "minecraft:player_head" and get(main, entity) or
			off.id == "minecraft:player_head" and get(off, entity) or nil
	else
		---@diagnostic disable-next-line: param-type-mismatch
		local item = entity:getHeldItem(offhand)
		return item.id == "minecraft:player_head" and get(item, entity) or nil
	end
end

---Finds a player punching the skull
---@param self FOXSkull.any
---@return Entity?
local function findPuncher(self)
	if not cachedPunches then
		cachedPunches = {}

		for _, entity in pairs(getEntities()) do
			---@diagnostic disable-next-line: undefined-field
			if entity.getSwingTime and entity:getSwingTime() == 1 then table.insert(cachedPunches, entity) end
		end
	end

	for _, entity in ipairs(cachedPunches) do
		if self --[[@as FOXSkull.block]].block and
			entity:getTargetedBlock(true, 5):getPos() == self --[[@as FOXSkull.block]].block:getPos() then
			return entity
			---@diagnostic disable-next-line: undefined-field
		elseif getHeldSkull(entity, entity:getSwingArm() == "OFF_HAND") == self then
			return entity
		end
	end
end

---Called once every tick, and stores loops to run tick functions of every skull
local function skullTick()
	cachedPunches = nil

	heldSkull = getHeldSkull(viewer)

	for _, self in pairs(all) do
		local priv = self[1]
		if priv.isErrored then goto continue end

		if self.tick then
			try(self, self.tick, self, self --[[@as FOXSkull.block]].block or self --[[@as FOXSkull.item]].item)
		end

		if self.onPunch then
			local puncher = findPuncher(self)

			if puncher then
				self.onPunch(self, puncher)
			end
		end

		::continue::
	end

	if selected then
		local priv = selected[1]

		local debugEnabled = client.isDebugOverlayEnabled()

		local str = priv.isErrored and priv.tooltip or debugEnabled and json.format(priv.vars) or nil
		priv.tooltip = str

		if debugEnabled then
			priv.hasVars = str and true
		end

		if not str then return end
		local off = client.getTextDimensions(str)

		if off.y < 128 then off.y = -64 end

		priv.tooltipOffset = (off * 0.125):augmented(-8)

		selected = nil
	end
end

function events.tick()
	queueTick()
	skullTick()
end

function events.world_tick()
	if player:isLoaded() then return end
	queueTick()
	skullTick()
end

--#ENDREGION
--#REGION Flush

---@type FOXSkull.key.internalID
local flushKey
local function flushRender()
	flushKey = next(all, flushKey)
	local self = all[flushKey]
	if not self then return end

	local block = self --[[@as FOXSkull.block]].block

	local timer = block and 50 or 2000
	if client.getSystemTime() - self[1].timestamp < timer then return end

	if block then
		local pos = block:getPos()
		if world.isChunkLoaded(pos) and world.getBlockState(pos) == block then return end
	end

	remove(flushKey)
	flushKey = nil
end

function events.render()
	flushRender()
end

function events.world_render()
	if player:isLoaded() then return end
	flushRender()
end

function events.resource_reload()
	for key in pairs(all) do
		remove(key)
	end
	flushKey = nil
end

--#ENDREGION

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkulls ♡˚
--==============================================================================================================================

---@class FOXSkullAPI.Index
---@field protected [FOXSkull.key.uuid] FOXSkull.any?
---@field protected [BlockState] FOXSkull.block?
---@field protected [ItemStack] FOXSkull.item?
---@field protected [Vector3] FOXSkull.block?

---@class FOXSkullAPI: FOXSkullAPI.Index
---@field block_init FOXSkullAPI.events.block
---@field item_init FOXSkullAPI.events.item
---@field skull_init FOXSkullAPI.events.any
---@field block_deinit FOXSkullAPI.events.block
---@field item_deinit FOXSkullAPI.events.item
---@field skull_deinit FOXSkullAPI.events.any
local skulls = {}

------------------------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkulls > Misc Functions ♡˚
------------------------------------------------------------------------------------------------

---Creates a new skull that isn't bound to an item or block
---@return FOXSkull.any
---@param name string?
---@param lore string?
---@nodiscard
function skulls.newSkull(name, lore)
	local self = new()

	self[1].generatedItem
		:setName(name)
		:setLore(lore)

	return self
end

local classKeys = {
	item = "item_init",
	block = "block_init",
	any = "skull_init",
}

---Creates a new skull mode which applies to all skulls with the name or mode variable
---
---Modes are applied on skull init, and the mode applied does not change when the variable is set after skull initialization
---@param key string
---@param class "item"|"block"|"any"?
---@param part ModelPart?
---@param init FOXSkullAPI.events.any?
---@param render FOXSkull.render.any?
---@param tick FOXSkull.tick.any?
---@param onPunch FOXSkull.onPunch.any?
---@overload fun(key: string, class: "block", part: ModelPart?, init: FOXSkullAPI.events.block?, render: FOXSkull.render.block?, tick: FOXSkull.tick.block?, onPunch: FOXSkull.onPunch.block?)
---@overload fun(key: string, class: "item", part: ModelPart?, init: FOXSkullAPI.events.item?, render: FOXSkull.render.item?, tick: FOXSkull.tick.item?, onPunch: FOXSkull.onPunch.item?)
function skulls.newMode(key, class, part, init, render, tick, onPunch)
	class = class or "any"

	assert(type(key) == "string", "String expected for param [1], got " .. type(key), 2)
	assert(type(class) == "string", "String expected for param [2], got " .. type(class), 2)
	assert(not part or type(part) == "ModelPart" or type(part) == "table",
		"ModelPart expected for param [3], got " .. type(part), 2)
	assert(not render or type(render) == "function", "Function expected for param [4], got " .. type(render), 2)
	assert(not tick or type(tick) == "function", "Function expected for param [5], got " .. type(tick), 2)
	assert(not onPunch or type(onPunch) == "function", "Function expected for param [6], got " .. type(onPunch), 2)

	---@type FOXSkullAPI.events.any
	skulls[classKeys[class]] = function(self)
		local mode = self:getVariable("mode") or self:getName()
		if not mode:lower():find(key:lower()) then return end

		self:model(part)

		init(self)
		self.tick = tick
		self.render = render
		self.onPunch = onPunch
	end
end

---Sets the ModelPart to use as the default for skulls
---@param model ModelPart?
---@param context FOXSkull.context.any|FOXSkull.context.any[]?
---@param copy boolean?
function skulls.setDefaultModel(model, context, copy)
	replaceModel(defaultModels, context, model, copy)
end

skulls.fragment = json.fragment

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkulls > Return ♡˚
------------------------------------------------------------------------------------------------

local meta = {
	__index = function(_, k) return get(k, player) end,
	__newindex = function(_, k, v)
		if not skullEvents[k] then
			error("Failed to set key " .. k, 2)
		elseif type(v) ~= "function" then
			error("Function expected, got " .. type(v), 2)
		end

		table.insert(skullEvents[k], v)
	end,
	__type = __brand,
	__version = __ver,
	__branch = __branch,
}

avatar:store("FOXSkullAPI", __sign)

return setmetatable(skulls, meta)

--#ENDREGION

--#ENDREGION
