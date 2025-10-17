--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's SkullAPI v1.0.0-dev
]]

---@diagnostic disable: undefined-doc-name, undefined-field
---@type FOXSkullAPI.Events
local events = require("./core/Events")
---@type FOXSkull
local skull = require("./FOXSkull")
local get = skull.get

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
		-- Only allow creating event functions

		if not events[k] then
			error("Failed to set key " .. k, 2)
		elseif type(v) ~= "function" then
			error("Function expected, got " .. type(v), 2)
		end

		table.insert(events[k], v)
	end,
	__type = "FOXSkullAPI",
	__version = "1.0.0",
	__branch = "dev"
})

-- Require all submodules recursively

for _, script in pairs(listFiles("./core", true)) do
	require(script)
end

for _, script in pairs(listFiles("./methods", true)) do
	require(script)
end

return skulls
