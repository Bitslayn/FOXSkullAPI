--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's JSON Userdata Notation v1.0.0-dev
]]

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

for name, data in pairs(avatar:getNBT().sounds or {}) do
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

---@class FOXJSON.AllocatedTexture
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
---@type table<string, FOXJSON.AllocatedTexture>
local textureQueue = {}
---@type string[]
local texturesUsedMap = {}
---@type table<string, FOXJSON.AllocatedTexture>
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

function events.tick()
	queueTick()
end

function events.world_tick()
	if player:isLoaded() then return end
	queueTick()
end

---Queues a texture to be allocated as soon as an opening becomes available
---@param name string
---@param bytes string|integer[]
---@param tbl table
---@param key any
local function addTexture(name, bytes, tbl, key)
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

---Searches for allocated textures contained in this table and removes them
---@param tbl table
local function removeTextures(tbl)
	local function search(curr)
		---@type FOXJSON.AllocatedTexture
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
	search(tbl)
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
--#REGION ˚♡ Utilities > JSON ♡˚
------------------------------------------------------------------------------------------------

---@alias FOXJSON.Vector number[]
---@alias FOXJSON.Matrix number[][]
---@alias FOXJSON.Entity string
---@alias FOXJSON.Block {state: string, pos: [number, number, number]}
---@alias FOXJSON.Item {stack: string, count: integer, damage: integer}
---@alias FOXJSON.Part string[]
---@alias FOXJSON.Sound {name: string, bytes: string|integer[]}
---@alias FOXJSON.Texture {name: string, bytes: string|integer[]}
---@alias FOXJSON.Fragment {name: string, uuid: string, chunk: string, len: integer, pos: integer}

local json = { removeTextures = removeTextures }

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
	---@return FOXJSON.Texture
	Texture = function(v)
		return setmetatable(v, { __type = "UnallocatedTexture" })
	end,
	---@param v table
	---@return FOXJSON.Fragment
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
					addTexture(unpacked[k].name, unpacked[k].bytes, unpacked, k)
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
---@return {type: string, value: FOXJSON.Fragment}[]
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
---@param frag FOXJSON.Fragment
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
			addTexture(source.tbl[source.key].name, source.tbl[source.key].bytes, source.tbl, source.key)
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
	---@param v FOXJSON.Texture
	UnallocatedTexture = function(v)
		return v.name, "UnallocatedTexture"
	end,

	---@param v FOXJSON.Fragment
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

return json
