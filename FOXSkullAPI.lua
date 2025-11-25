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

---Raises an error if the value of its argument v is false (i.e., `nil` or `false`); otherwise, returns all its arguments. In case of error, `message` is the error object; when absent, it defaults to `"assertion failed!"`
---@generic T
---@param v? T
---@param message? any
---@param level? integer
---@return T v
local function assert(v, message, level)
	return v or error(message or "Assertion failed!", (level or 1) + 1)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Utilities > Find Script ♡˚
------------------------------------------------------------------------------------------------

local pathJson = toJson(listFiles(nil, true))

---Returns the script path that matches the given pattern
---@param pattern string
---@return string?
local function findScript(pattern)
	local formattedPattern = pattern
		:gsub('"', '\\"') -- Escape all quotation marks
		:gsub("^%^", '%%f[^"]') -- Replace start of pattern ^ with "
		:gsub("%$$", '%%f["]') -- Replace end of pattern $ with "
		:gsub("^", '[^"]*') -- Pad start of pattern to "
		:gsub("$", '[^"]*') -- Pad end of pattern to "

	return pathJson:match(formattedPattern)
end

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkull ♡˚
--==============================================================================================================================

---@class FOXSkullAPI.Skulls.Any

---@class FOXSkullAPI.Skulls.Block: FOXSkullAPI.Skulls.Any

---@class FOXSkullAPI.Skulls.Item: FOXSkullAPI.Skulls.Any

---@alias FOXSkullAPI.Functions.Any fun(skull: FOXSkullAPI.Skulls.Any)
---@alias FOXSkullAPI.Functions.Block fun(skull: FOXSkullAPI.Skulls.Block, block: BlockState)
---@alias FOXSkullAPI.Functions.Item fun(skull: FOXSkullAPI.Skulls.Item, item: ItemStack)
---@alias FOXSkullAPI.Functions.Render fun(delta: number, skull: FOXSkullAPI.Skulls.Any, ctx: Event.SkullRender.context)
---@alias FOXSkullAPI.Functions.Tick fun(skull: FOXSkullAPI.Skulls.Any)
---@alias FOXSkullAPI.Functions.Other fun(skull: FOXSkullAPI.Skulls.Any)

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Groups ♡˚
------------------------------------------------------------------------------------------------

--[[ Dev note:
	This enum is written like a tree to avoid recursion
	There is nothing preventing the ungroup function from forming an infinite loop, and as such, the structure of this table should be kept linear
]]

---@enum FOXSkullAPI.Groups.Enum
local context_groups = {
	LEFT_HAND = { "FIRST_PERSON_LEFT_HAND", "THIRD_PERSON_LEFT_HAND" },
	RIGHT_HAND = { "FIRST_PERSON_RIGHT_HAND", "THIRD_PERSON_RIGHT_HAND" },
	FIRST_PERSON = { "FIRST_PERSON_LEFT_HAND", "FIRST_PERSON_RIGHT_HAND" },
	THIRD_PERSON = { "THIRD_PERSON_LEFT_HAND", "THIRD_PERSON_RIGHT_HAND" },
	HANDS = { "LEFT_HAND", "RIGHT_HAND" },
	CONTAINER = { "GUI", "OTHER" },
	ITEM = { "HANDS", "HEAD", "FIXED", "GROUND", "CONTAINER" },
	BLOCK = { "FLOOR_BLOCK", "WALL_BLOCK" },
	ALL = { "ITEM", "BLOCK" },
}

---@alias FOXSkullAPI.Groups
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
---| "FIXED" Skull placed in an item frame **Figura 0.1.6+**
---| "GROUND" Skull dropped on the floor **Figura 0.1.6+**
---| "BLOCK" Any skull block
---| "FLOOR_BLOCK" Skull placed on the floor
---| "WALL_BLOCK" Skull placed on a wall
---| "ALL" Any skull
---| "OTHER" Fallback context

---Gives a table containing contexts in the given group
---@param v FOXSkullAPI.Groups
---@return FOXSkullAPI.Groups[]
local function ungroup(v)
	local r = {}

	---@param g string
	local function p(g)
		local t = context_groups[g]
		if t then
			for _, h in ipairs(t) do
				p(h)
			end
		else
			table.insert(r, g)
		end
	end

	p(string.upper(v))

	return r
end

--#ENDREGION -----------------------------------------------------------------------------------
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
	---Called whenever any skull starts rendering. This is called alongside block_init or item_init.
	---@type FOXSkullAPI.Functions.Any[]
	skull_init = setmetatable({}, event_meta),
	---Called whenever skulls have started rendering blocks.
	---@type FOXSkullAPI.Functions.Block[]
	block_init = setmetatable({}, event_meta),
	---Called whenever skulls have started rendering on an entity, or inside a container.
	---@type FOXSkullAPI.Functions.Item[]
	item_init = setmetatable({}, event_meta),
	---Called whenever any skull stops rendering. This is called alongside block_deinit or item_deinit.
	---@type FOXSkullAPI.Functions.Any[]
	skull_deinit = setmetatable({}, event_meta),
	---Called whenever skulls have stopped rendering as blocks.
	---@type FOXSkullAPI.Functions.Block[]
	block_deinit = setmetatable({}, event_meta),
	---Called whenever skulls have stopped rendering on an entity, or inside a container.
	---@type FOXSkullAPI.Functions.Item[]
	item_deinit = setmetatable({}, event_meta),
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
	---Called on a skull that errors.
	---@type FOXSkullAPI.Functions.Other[]
	skull_error = setmetatable({}, event_meta),
}

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkullAPI ♡˚
--==============================================================================================================================

---@class FOXSkullAPI.Index
---@field protected [string] FOXSkullAPI.Skulls.Any?
---@field protected [BlockState] FOXSkullAPI.Skulls.Block?
---@field protected [ItemStack] FOXSkullAPI.Skulls.Item?
---@field protected [Vector3] FOXSkullAPI.Skulls.Block?

---TODO Add quick start guide and link to wiki here
---@class FOXSkullAPI: FOXSkullAPI.Index
---@field block_init FOXSkullAPI.Functions.Block
---@field item_init FOXSkullAPI.Functions.Item
---@field skull_init FOXSkullAPI.Functions.Any
---@field block_deinit FOXSkullAPI.Functions.Block
---@field item_deinit FOXSkullAPI.Functions.Item
---@field skull_deinit FOXSkullAPI.Functions.Any
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
