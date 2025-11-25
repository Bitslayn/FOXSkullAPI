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
--#REGION ˚♡ Events ♡˚
--==============================================================================================================================

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

---Proxies the event tables, allowing for adding new events by calling a __newindex
local event_proxy_meta = {
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
}

---@alias FOXSkullAPI.Functions.Block fun(skull: FOXSkull.block, block: BlockState)
---@alias FOXSkullAPI.Functions.Item fun(skull: FOXSkull.item, item: ItemStack)
---@alias FOXSkullAPI.Functions.Any fun(skull: FOXSkull.any)
---@alias FOXSkullAPI.Functions.Render fun(delta: number, skull: FOXSkull.any, ctx: Event.SkullRender.context)
---@alias FOXSkullAPI.Functions.Tick fun(skull: FOXSkull.any)
---@alias FOXSkullAPI.Functions.Other fun(skull: FOXSkull.any)

---@class FOXSkullAPI.Events
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

local skull_event = {
	---Called whenever any skull starts rendering. This is called alongside block_init or item_init.
	skull_init = setmetatable({}, event_meta),
	---Called whenever skulls have started rendering blocks.
	block_init = setmetatable({}, event_meta),
	---Called whenever skulls have started rendering on an entity, or inside a container.
	item_init = setmetatable({}, event_meta),
	---Called whenever any skull stops rendering. This is called alongside block_deinit or item_deinit.
	skull_deinit = setmetatable({}, event_meta),
	---Called whenever skulls have stopped rendering as blocks.
	block_deinit = setmetatable({}, event_meta),
	---Called whenever skulls have stopped rendering on an entity, or inside a container.
	item_deinit = setmetatable({}, event_meta),
	---Called on each skull that renders regardless of its type, for each context it renders in, before updating its model and calling its render function.
	pre_render = setmetatable({}, event_meta),
	---Called on each skull that renders regardless of its type, for each context it renders in, after updating its model and calling its render function.
	post_render = setmetatable({}, event_meta),
	---Called on each skull that renders but only once per tick just like the skull_tick function. Ran before running the skull's tick function.
	pre_tick = setmetatable({}, event_meta),
	---Called on each skull that renders but only once per tick just like the skull_tick function. Ran after running the skull's tick function.
	post_tick = setmetatable({}, event_meta),
	---Called on a skull that errors.
	skull_error = setmetatable({}, event_meta),
}

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkull ♡˚
--==============================================================================================================================

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXSkullAPI ♡˚
--==============================================================================================================================

---@class FOXSkullAPI.Index
---@field protected [string] FOXSkull.any?
---@field protected [BlockState] FOXSkull.block?
---@field protected [ItemStack] FOXSkull.item?
---@field protected [Vector3] FOXSkull.block?

---@class FOXSkullAPI: FOXSkullAPI.Events, FOXSkullAPI.Index
local skulls = setmetatable({
	[1] = skull_event,
}, event_proxy_meta)

return skulls

--#ENDREGION
