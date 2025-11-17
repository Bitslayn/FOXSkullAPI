--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Animation Parser v1.0.0-dev
]]

--==============================================================================================================================
--#REGION ˚♡ Animation Provider ♡˚
--==============================================================================================================================

---@alias FOXAnimParser.loop
---| "once" This animation plays once then stops
---| "hold" This animation plays once then pauses on the last frame
---| "loop" This animation plays repeatedly
---@alias FOXAnimParser.type
---| "pos" Position keyframe
---| "rot" Rotation keyframe
---| "scl" Scale keyframe
---@alias FOXAnimParser.interpolation
---| "linear" Linear interpolation mode
---| "catmullrom" Smooth interpolation mode
---| "bezier" Bezier interpolation mode
---| "step" Step interpolation mode
---@alias FOXAnimParser.axis number|string Contains a number or molang string
---@alias FOXAnimParser.transform [FOXAnimParser.axis, FOXAnimParser.axis, FOXAnimParser.axis]
---@class FOXAnimParser.anim
---@field mdls FOXAnimParser.animator[] This animation's animators
---@field len number This animation's length in seconds
---@field loop FOXAnimParser.loop This animation's loop mode
---@field name string This animation's name
---@field ovr boolean Whether this animation is set to override
---@alias FOXAnimParser.animator table<FOXAnimParser.type, FOXAnimParser.keyframe[]>
---@class FOXAnimParser.keyframe
---@field int FOXAnimParser.interpolation This keyframe's interpolation mode
---@field type FOXAnimParser.type This keyframe's type
---@field time number This keyframe's timestamp in seconds
---@field mdl ModelPart Animator affected by this keyframe
---@field pre FOXAnimParser.transform This keyframe's primary transform
---@field bl FOXAnimParser.transform? Bezier left
---@field br FOXAnimParser.transform? Bezier right
---@field blt FOXAnimParser.transform? Bezier left time
---@field brt FOXAnimParser.transform? Bezier right time
---@type FOXAnimParser.anim[]
local anims = {}

---Pushes the given data table onto the frames table
---@param mdls table<ModelPart, FOXAnimParser.animator>
---@param path string
---@param data table<FOXAnimParser.type, FOXAnimParser.keyframe[]>
local function pushKeyframes(mdls, path, data)
	local part = models
	for name in path:match("^models%.(.*)$") --[[@as string]]:gmatch("[^%.]*") do
		part = part[name]
	end

	mdls[part] = {}
	for type, frames in pairs(data) do
		mdls[part][type] = frames
		table.sort(frames, function(a, b)
			return a.time < b.time
		end)
	end
end

---Searches for and localizes animations from this avatar's NBT
---@param chld table
---@param path string?
local function searchAnims(chld, path)
	for _, mdl in ipairs(chld) do
		if mdl.chld then
			searchAnims(mdl.chld, path .. "." .. mdl.name)
		end

		for _, anim in ipairs(mdl.anim or {}) do
			local id = anim.id + 1

			if not anims[id] then
				local nbt = avatar:getNBT().animations[id]

				anims[id] = {
					mdls = {},
					len = nbt.len or 0,
					loop = nbt.loop or "once",
					name = nbt.name,
					ovr = not not nbt.ovr,
				}
			end

			pushKeyframes(anims[id].mdls, path .. "." .. mdl.name, anim.data)
		end
	end
end
searchAnims(avatar:getNBT().models.chld, "models")

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Interplation ♡˚
--==============================================================================================================================



--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Class ♡˚
--==============================================================================================================================

local class = {}
class.__index = class

function class.new()

end

--#ENDREGION
