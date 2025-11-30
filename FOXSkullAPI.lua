--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's SkullAPI v1.0.0-dev

Github: https://github.com/Bitslayn/FOXSkullAPI
Docs: https://github.com/Bitslayn/FOXSkullAPI/wiki
]]

--==============================================================================================================================
--#REGION ˚♡ Utilities ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Assert ♡˚
------------------------------------------------------------------------------------------------

---Custom assertion function with integer level
---@generic T
---@param v? T
---@param m? any
---@param l? integer
---@return T v
local function assert(v, m, l)
	return v or error(m, (l or 1) + 1)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Find Script ♡˚
------------------------------------------------------------------------------------------------

local path_json = toJson(listFiles(nil, true))

---Returns the script path that matches the given pattern
---@param p string
---@return string?
local function path(p)
	return path_json:match(p
		:gsub('"', '\\"') -- Escape all quotation marks
		:gsub("^%^", '%%f[^"]') -- Replace start of pattern ^ with "
		:gsub("%$$", '%%f["]') -- Replace end of pattern $ with "
		:gsub("^", '[^"]*') -- Pad start of pattern to "
		:gsub("$", '[^"]*') -- Pad end of pattern to "
	)
end

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkull ♡˚
--==============================================================================================================================

---@class FOXSkullAPI.Skull
---@field block BlockState?
---@field item ItemStack?
---@field entity Entity?
---@field context FOXSkullAPI.Context
---@field package [1] FOXSkullAPI.Skull.Private
local class = {}

---@class FOXSkullAPI.Skull.Private
---@field models table<FOXSkullAPI.Context.Groups, ModelPart>
---@field visible boolean
---@field id string
---@field uuid string
---@field timestamp integer

---@alias FOXSkullAPI.Functions.Skull fun(skull: FOXSkullAPI.Skull, block: BlockState?, item: ItemStack?, entity: Entity?, context: FOXSkullAPI.Context)
---@alias FOXSkullAPI.Functions.Render fun(delta: number, ctx: FOXSkullAPI.Context, skull: FOXSkullAPI.Skull)
---@alias FOXSkullAPI.Functions.Tick fun(skull: FOXSkullAPI.Skull)
---@alias FOXSkullAPI.Functions.Other fun(skull: FOXSkullAPI.Skull)



---@alias FOXSkullAPI.Skull.Keys
---| string A skull UUID
---| BlockState A skull block
---| ItemStack A skull item
---| Vector3 A skull position

---Stores all skulls with id keys
---@type table<string, FOXSkullAPI.Skull>
local all = {}
---Stores uuid, id pairs
---@type table<string, string>
local uuids = {}

------------------------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Events ♡˚
------------------------------------------------------------------------------------------------

---Optimizes and allows for calling events
local event_meta = {
	__call = function(s, ...)
		return s.c and s.c(...)
	end,
	__newindex = function(s, k, v)
		rawset(s, k, v)

		-- Generates a return function

		-- local f1=_ENV[1]
		-- local f2=_ENV[2]
		-- local f3=_ENV[3]
		-- return function(...)f1(...)f2(...)f3(...)end

		local l, c = {}, {}
		for i = 1, #s do
			l[i] = string.format("local f%d=_ENV[%d]", i, i)
			c[i] = string.format("f%d(...)", i)
		end

		local f = load(string.format(
			"%s\nreturn function(...)%send",
			table.concat(l, "\n"),
			table.concat(c, "")
		), "event_meta", s)

		-- Stores a function with all event functions localized

		-- function(...) f1(...); f2(...); f3(...); end

		rawset(s, "c", f())
	end,
}

---@class FOXSkullAPI.Events
local skull_event = {
	---Called whenever any skull starts rendering.
	---@type FOXSkullAPI.Functions.Skull[]
	skull_init = setmetatable({}, event_meta),
	---Called whenever any skull stops rendering.
	---@type FOXSkullAPI.Functions.Skull[]
	skull_deinit = setmetatable({}, event_meta),
	---Called on a skull that errors.
	---@type FOXSkullAPI.Functions.Other[]
	skull_error = setmetatable({}, event_meta),
	---Called on each skull that renders regardless of its type, for each context it renders in, before updating its model and calling its render function.
	---@type FOXSkullAPI.Functions.Render[]
	pre_render = setmetatable({}, event_meta),
	---Called on each skull that renders regardless of its type, for each context it renders in, after updating its model and calling its render function.
	---@type FOXSkullAPI.Functions.Render[]
	post_render = setmetatable({}, event_meta),
	---Called on each skull that renders but only once per tick just like the skull_tick function. Ran before running the skull's tick function.
	---@type FOXSkullAPI.Functions.Tick[]
	pre_tick = setmetatable({}, event_meta),
	---Called on each skull that renders but only once per tick just like the skull_tick function. Ran after running the skull's tick function.
	---@type FOXSkullAPI.Functions.Tick[]
	post_tick = setmetatable({}, event_meta),
}

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Groups ♡˚
------------------------------------------------------------------------------------------------

---@alias FOXSkullAPI.Context
---| "FIRST_PERSON_LEFT_HAND" Skull held in the left hand, in first person
---| "FIRST_PERSON_RIGHT_HAND" Skull held in the right hand, in first person
---| "THIRD_PERSON_LEFT_HAND" Skull held in the left hand, in third person
---| "THIRD_PERSON_RIGHT_HAND" Skull held in the right hand, in third person
---| "HEAD" Skull worn in the helmet slot
---| "GUI" Skull inside an inventory or GUI
---| "GROUND" Skull dropped on the floor **Figura 0.1.6+**
---| "FIXED" Skull placed in an item frame **Figura 0.1.6+**
---| "BLOCK" Skull placed as a block
---| "OTHER" Fallback context

---@alias FOXSkullAPI.Context.Groups
---| "HANDS" Skull held in either hand
---| "LEFT_HAND" Skull held in left hand
---| "RIGHT_HAND" Skull held in right hand
---| "FIRST_PERSON" Skull held in either hand, in first person
---| "THIRD_PERSON" Skull held in either hand, in third person
---| "FIRST_PERSON_LEFT_HAND" Skull held in the left hand, in first person
---| "FIRST_PERSON_RIGHT_HAND" Skull held in the right hand, in first person
---| "THIRD_PERSON_LEFT_HAND" Skull held in the left hand, in third person
---| "THIRD_PERSON_RIGHT_HAND" Skull held in the right hand, in third person
---| "ITEM" Any skull item
---| "CONTAINER" Skull inside an inventory or GUI **In Figura 0.1.5, this would also target skulls displayed on the floor and in an item frame**
---| "HEAD" Skull worn in the helmet slot
---| "GUI" Skull inside an inventory or GUI
---| "GROUND" Skull dropped on the floor **Figura 0.1.6+**
---| "FIXED" Skull placed in an item frame **Figura 0.1.6+**
---| "BLOCK" Skull placed as a block
---| "ALL" Any skull
---| "OTHER" Fallback context

---@type table<string, string[]>
local context_groups = {
	LEFT_HAND = { "FIRST_PERSON_LEFT_HAND", "THIRD_PERSON_LEFT_HAND" },
	RIGHT_HAND = { "FIRST_PERSON_RIGHT_HAND", "THIRD_PERSON_RIGHT_HAND" },
	FIRST_PERSON = { "FIRST_PERSON_LEFT_HAND", "FIRST_PERSON_RIGHT_HAND" },
	THIRD_PERSON = { "THIRD_PERSON_LEFT_HAND", "THIRD_PERSON_RIGHT_HAND" },
	HANDS = { "LEFT_HAND", "RIGHT_HAND" },
	CONTAINER = { "GUI", "OTHER" },
	ITEM = { "HANDS", "HEAD", "FIXED", "GROUND", "CONTAINER" },
	ALL = { "ITEM", "BLOCK" },
}

---@type table<FOXSkullAPI.Context.Groups, true>[]
local group_cache = {}

---Gives a table containing contexts in the given group
---@param v FOXSkullAPI.Context.Groups|FOXSkullAPI.Context.Groups[]
---@return table<FOXSkullAPI.Context.Groups, true>
local function ungroup(v)
	if group_cache[v] then return group_cache[v] end

	local r = {}

	---Add keys to table, deep ungrouping where necessary
	---@param g string
	local function p(g)
		local t = context_groups[g]
		if t then
			for _, h in ipairs(t) do
				p(h)
			end
		else
			r[g] = true
		end
	end

	-- Initialize ungrouping

	if type(v) == "string" then
		p(string.upper(v))
		group_cache[v] = r
	else
		for _, h in ipairs(v) do
			p(h)
		end
	end

	return r
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Models ♡˚
------------------------------------------------------------------------------------------------

---Copies the tasks from the source model to the destination model
---
---This is a backport of a built-in 0.1.6 feature
---@param s ModelPart
---@param d ModelPart
local function copy_tasks(s, d)
	for _, task in pairs(s:getTask()) do
		d:addTask(task)
	end
end

---Copies a model and turns it into a skull model
---@param m ModelPart?
---@return ModelPart?
local function copy_model(m)
	if type(m) ~= "ModelPart" then return end

	local t = next(m:getTask())

	local c = m:copy(m:getName())
		:parentType("Skull")
		:visible(false)
		:moveTo(models)

	if t and not next(c:getTask()) then
		copy_tasks(m, c)
	end

	return c
end

---Sets the model of a skull
---@param s FOXSkullAPI.Skull
---@param m ModelPart
---@param g FOXSkullAPI.Context.Groups|FOXSkullAPI.Context.Groups[]
local function set_model(s, m, g)
	local p = s[1].models

	for c in pairs(ungroup(g)) do
		if p[c] then
			p[c]:remove()
		end
		p[c] = copy_model(m)
	end

	return s
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Methods ♡˚
------------------------------------------------------------------------------------------------

---Sets this skull's model
---@param model ModelPart
---@param context FOXSkullAPI.Context.Groups|FOXSkullAPI.Context.Groups[]?
---@return self
function class:model(model, context)
	return set_model(self, model, context or "OTHER")
end

---Sets this skull's model
---@param model ModelPart
---@param context FOXSkullAPI.Context.Groups|FOXSkullAPI.Context.Groups[]?
---@return self
function class:setModel(model, context)
	return set_model(self, model, context or "OTHER")
end

---Returns if this skull's current context is of a context group
---@param context FOXSkullAPI.Context.Groups|FOXSkullAPI.Context.Groups[]?
---@return boolean
---@nodiscard
function class:hasContext(context)
	return ungroup(context)[self.context] or false
end

---Removes this skull
---
---This function does not call the skull_deinit event
function class:remove()
	local priv = self[1]
	uuids[priv.uuid] = nil
	all[priv.id] = nil

	for _, m in pairs(priv.models) do
		m:remove()
	end
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Accessor ♡˚
------------------------------------------------------------------------------------------------

--#REGION Get

---@type table<string, fun(key: FOXSkullAPI.Skull.Keys, entity: Entity?): string>
local type_id = {
	---@param key string
	---@return string
	string = function(key)
		return uuids[key]
	end,
	---@param key BlockState
	---@return string
	BlockState = function(key)
		return key:getPos():toString()
	end,
	---@param key ItemStack
	---@return string
	ItemStack = function(key)
		return key:getCount() .. key:toStackString()
	end,
	---@param key Vector3
	---@return string
	Vector3 = function(key)
		return key:toString()
	end,
}

---Formats a supported key into an internalID
---
---Returns nil if the key is of an invalid type
---@param key FOXSkullAPI.Skull.Keys
---@return string?
local function get_id(key)
	local f = type_id[type(key)]
	if f then return f(key) end
end

---Gets a skull that has been initialized
---
---Returns nil if a skull with the given key does not exist
---@param key FOXSkullAPI.Skull.Keys
---@return FOXSkullAPI.Skull?
local function get(key)
	return all[key] or all[get_id(key)]
end

--#ENDREGION
--#REGION New

local skull_meta = { __index = class, __type = "FOXSkull" }

---Creates and returns a new skull with the given BlockState or ItemStack
---
---Calls the init event
---
---Returns nil if the key is of an invalid type
---@param block BlockState
---@param item ItemStack
---@param entity Entity
---@param context FOXSkullAPI.Context
---@return FOXSkullAPI.Skull
local function new(block, item, entity, context)
	local self = setmetatable({
		block = block,
		item = item,
		entity = entity,
		context = context,
	}, skull_meta)

	local id = get_id(block or item)
	local uuid = client.intUUIDToString(client.generateUUID())
	self[1] = {
		models = {},
		visible = true,
		id = id,
		uuid = uuid,
		timestamp = client.getSystemTime(),
	}

	uuids[uuid] = id
	all[id] = self

	skull_event.skull_init(self, item, block)

	return self
end

--#ENDREGION
--#REGION Remove

---Removes a skull by its generic key
---
---Calls the deinit event
---@param key FOXSkullAPI.Skull.Keys
local function remove(key)
	local self = all[key] or all[get_id(key)]
	if not self then return end

	skull_event.skull_deinit(self, self.item, self.block)

	self:remove()
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Service ♡˚
------------------------------------------------------------------------------------------------

function events.skull_render(delta, block, item, entity, context)
	local self = get(block or item) or new(block, item, entity, context --[[@as FOXSkullAPI.Context]])
	
end

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkullAPI ♡˚
--==============================================================================================================================

---@class FOXSkullAPI.Index
---@field protected [string] FOXSkullAPI.Skull?
---@field protected [BlockState] FOXSkullAPI.Skull?
---@field protected [ItemStack] FOXSkullAPI.Skull?
---@field protected [Vector3] FOXSkullAPI.Skull?

---TODO Add quick start guide and link to wiki here
---@class FOXSkullAPI: FOXSkullAPI.Index
---@field skull_init FOXSkullAPI.Functions.Skull
---@field skull_deinit FOXSkullAPI.Functions.Skull
---@field pre_render FOXSkullAPI.Functions.Render
---@field post_render FOXSkullAPI.Functions.Render
---@field pre_tick FOXSkullAPI.Functions.Tick
---@field post_tick FOXSkullAPI.Functions.Tick
---@field skull_error FOXSkullAPI.Functions.Other
---@field protected [1] FOXSkullAPI.Events
local skulls = setmetatable({}, {
	__index = function(s, k)
		return s[1][k]
	end,
	__newindex = function(s, k, v)
		s, k = s[1], string.lower(k)

		local t = type(v)
		assert(t == "function", "Expected Function, but got " .. t, 2)
		assert(s[k], 'Cannot assign value on key "' .. k .. '"', 2)

		table.insert(s[k], v)
	end,
})

rawset(skulls, 1, skull_event)

return skulls

--#ENDREGION
