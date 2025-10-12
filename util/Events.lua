---@meta FOXSkull

---@alias FOXSkullAPI.Events.block fun(skull: FOXSkull.block)
---@alias FOXSkullAPI.Events.item fun(skull: FOXSkull.item)
---@class FOXSkullAPI.Events
local events = {
	---@type FOXSkullAPI.Events.block[]
	block_init = {},
	---@type FOXSkullAPI.Events.item[]
	item_init = {},
	---@type FOXSkullAPI.Events.block[]
	block_deinit = {},
	---@type FOXSkullAPI.Events.item[]
	item_deinit = {},
}

local initState = {
	["FOXSkull.block"] = function(skull)
		for _, func in pairs(events.block_init) do
			func(skull)
		end
	end,
	["FOXSkull.item"] = function(skull)
		for _, func in pairs(events.item_init) do
			func(skull)
		end
	end,
}

local deinitState = {
	["FOXSkull.block"] = function(skull)
		for _, func in pairs(events.block_deinit) do
			func(skull)
		end
	end,
	["FOXSkull.item"] = function(skull)
		for _, func in pairs(events.item_deinit) do
			func(skull)
		end
	end,
}

---@class FOXSkullAPI.Events.call
local call = {
	init = function(skull)
		local state = initState[type(skull)]
		if not state then return end
		state(skull)
	end,
	deinit = function(skull)
		local state = deinitState[type(skull)]
		if not state then return end
		state(skull)
	end,
}

return events, call
