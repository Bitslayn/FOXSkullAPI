--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's SkullAPI Addon
]]

local proj_model = models:newPart("proj_model", "Skull"):visible(false)

local wall_dirs = { north = 0, east = 90, south = 180, west = 270 }
local wall_offset = vec(0, -4, -4)

local mat_pos = matrices.translate4
local mat_yaw = matrices.yRotation4

---Transforms the projection around the given skull
---@param block BlockState
local function proj_mov(block)
	local center

	if block.id == "minecraft:player_head" then
		center = mat_yaw(block.properties.rotation * 22.5)
	else
		center = mat_pos(wall_offset) * mat_yaw(wall_dirs[block.properties.facing])
	end

	proj_model:matrix(center * mat_pos(block:getPos():add(0.5, 0, 0.5) * -16))
end

return function(skulls)
	---@class FOXSkullAPI
	skulls = skulls

	skulls.projection = proj_model

	local do_render
	function events.render()
		do_render = true
	end

	function events.world_render()
		if player:isLoaded() then return end
		do_render = true
	end

	function events.skull_render(_, block)
		proj_model:visible(do_render and not not block)
		if not block then return end

		proj_mov(block)
		do_render = false
	end
end
