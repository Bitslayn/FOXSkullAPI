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
---@alias FOXAnimParser.transform [number, number, number]|Vector3
---@class FOXAnimParser.anim
---@field keys table<string, FOXAnimParser.animator> This animation's animators
---@field len number This animation's length in seconds
---@field loop FOXAnimParser.loop This animation's loop mode
---@field mdl string This animation's root ModelPart path
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
---@type table<Animation, FOXAnimParser.anim>
local anims = {}

---Pushes the given data table onto the frames table
---@param mdls table<string, FOXAnimParser.animator>
---@param path string
---@param data table<FOXAnimParser.type, FOXAnimParser.keyframe[]>
local function pushKeyframes(mdls, path, data)
	path = path:gsub("models.", "")

	mdls[path] = {}
	for type, frames in pairs(data) do
		mdls[path][type] = frames
		for _, frame in ipairs(frames) do
			frame.pre = vec(table.unpack(frame.pre))
			frame.bl = frame.bl and vec(table.unpack(frame.bl))
			frame.br = frame.br and vec(table.unpack(frame.br))
			frame.blt = frame.blt and vec(table.unpack(frame.blt))
			frame.brt = frame.brt and vec(table.unpack(frame.brt))
		end
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

			local nbt = avatar:getNBT().animations[id]
			---@type Animation
			local animation = animations[nbt.mdl][nbt.name]

			if not anims[animation] then
				anims[animation] = {
					keys = {},
					len = nbt.len or 0,
					loop = nbt.loop or "once",
					mdl = nbt.mdl,
					name = nbt.name,
					ovr = not not nbt.ovr,
				}
			end

			pushKeyframes(anims[animation].keys, path .. "." .. mdl.name, anim.data)
		end
	end
end
searchAnims(avatar:getNBT().models.chld, "models")

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ ModelPart Helpers ♡˚
--==============================================================================================================================

---Converts a ModelPart into a model path string
---@param model ModelPart
---@return string
local function toPath(model)
	local path = {}
	while model:getParent() do
		table.insert(path, 1, model:getName())
		model = model:getParent()
	end
	return table.concat(path, ".")
end

---Converts a model path string into a ModelPart
---@param path string
---@param part ModelPart?
---@return ModelPart
local function parsePath(path, part)
	part = part or models
	for s in path:gmatch("[^%.]*") do
		part = part[s] or part:getName() == s and part
	end
	return part
end

---Deep copies the ModelPart
---@param part ModelPart
---@param name string?
---@return ModelPart
local function deepCopy(part, name)
	local copy = part:copy(name or part:getName())
	for _, child in ipairs(part:getChildren()) do
		copy:removeChild(child)
		deepCopy(child):moveTo(copy)
	end
	return copy
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Interplation ♡˚
--==============================================================================================================================

---@param p0 number
---@param p1 number
---@param p2 number
---@param p3 number
---@param t number
---@return number
local function catmullRom(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return ((p1 * 2) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3) *
		0.5
end

---@param p0 Vector3
---@param p1 Vector3
---@param p2 Vector3
---@param p3 Vector3
---@param t number
---@return Vector3
local function catmullRomInterpolate(p0, p1, p2, p3, t)
	return vec(
		catmullRom(p0.x, p1.x, p2.x, p3.x, t),
		catmullRom(p0.y, p1.y, p2.y, p3.y, t),
		catmullRom(p0.z, p1.z, p2.z, p3.z, t)
	)
end

---@param p0 number
---@param c0 number
---@param c1 number
---@param p1 number
---@param t number
---@return number
local function cubicBezier(p0, c0, c1, p1, t)
	local u = 1 - t
	local tt = t * t
	local uu = u * u
	local uuu = uu * u
	local ttt = tt * t
	local p = uuu * p0
	p = p + 3 * uu * t * c0
	p = p + 3 * u * tt * c1
	p = p + ttt * p1
	return p
end

---@param p0 Vector3
---@param c0 Vector3
---@param c1 Vector3
---@param p1 Vector3
---@param t number
---@return Vector3
local function bezierInterpolate(p0, c0, c1, p1, t)
	if not c0 then c0 = p0 end
	if not c1 then c1 = p1 end
	return vec(
		cubicBezier(p0.x, c0.x, c1.x, p1.x, t),
		cubicBezier(p0.y, c0.y, c1.y, p1.y, t),
		cubicBezier(p0.z, c0.z, c1.z, p1.z, t)
	)
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Class ♡˚
--==============================================================================================================================

---@alias FOXAnim.state
---| "stopped"
---| "playing"
---| "paused"
---@class FOXAnim.priv
---@field mdl ModelPart
---@field sub integer
---@field anim FOXAnimParser.anim
---@field state FOXAnim.state
---@field speed number
---@field time number Current time in seconds
---@field render number Time this animation was last rendered in ms
---@field len number
---@field loop FOXAnimParser.loop
---@field keys table<ModelPart, FOXAnimParser.animator>
---@class FOXAnim
---@field package [1] FOXAnim.priv
---@field package __index FOXAnim
local class = {}
class.__index = class

---@class FOXAnimAPI
local api = {}

---Creates and returns an animation bound to this model
---@param model ModelPart
---@param animation Animation
---@return FOXAnim
function api.new(model, animation)
	local anim = anims[animation]
	local sub = anim.mdl:find(model:getName())

	assert(sub, "ModelPart cannot be used with this animation!", 2)

	---@class FOXAnim
	---@diagnostic disable-next-line: missing-fields
	local self = { [1] = {} }
	---@class FOXAnim.priv
	local priv = self[1]
	priv.mdl = model
	priv.sub = sub
	priv.anim = anim
	priv.state = "stopped"
	priv.speed = 1
	priv.time = 0
	priv.render = client.getSystemTime()
	priv.len = anim.len
	priv.loop = anim.loop
	priv.keys = {}

	for key, data in pairs(anim.keys) do
		local mdl = parsePath(key:sub(sub))
		if mdl then
			priv.keys[mdl] = data
		end
	end

	return setmetatable(self, class)
end

---Starts or resumes this animation
---@return self
function class:play()
	local priv = self[1]
	if priv.state == "playing" then return self end

	priv.state = "playing"

	return self
end

---Stops this animation
---@return self
function class:stop()
	local priv = self[1]
	if priv.state == "stopped" then return self end

	priv.state = "stopped"

	return self
end

---Pauses this animation
---@return self
function class:pause()
	local priv = self[1]
	if priv.state == "paused" then return self end

	priv.state = "paused"

	return self
end

---@param frames FOXAnimParser.keyframe[]
---@param time number
---@return FOXAnimParser.keyframe?, FOXAnimParser.keyframe?, FOXAnimParser.keyframe?, FOXAnimParser.keyframe?
local function findFrames(frames, time)
	local n = #frames

	if time <= frames[1].time then
		return frames[1], frames[1], frames[1], frames[1]
	end

	if time >= frames[n].time then
		return frames[n], frames[n], frames[n], frames[n]
	end

	local left = 1
	local right = n - 1
	while left <= right do
		local mid = math.floor((left + right) / 2)
		if frames[mid].time <= time and time < frames[mid + 1].time then
			local p0 = (mid > 1) and frames[mid - 1] or frames[mid]
			local p1 = frames[mid]
			local p2 = frames[mid + 1]
			local p3 = (mid < n - 1) and frames[mid + 2] or frames[mid + 1]
			return p0, p1, p2, p3
		elseif time < frames[mid].time then
			right = mid - 1
		else
			left = mid + 1
		end
	end
end

---@private
---@param part ModelPart
---@param transform_type string
---@param p0 FOXAnimParser.keyframe
---@param p1 FOXAnimParser.keyframe
---@param p2 FOXAnimParser.keyframe
---@param p3 FOXAnimParser.keyframe
---@param t number
function class:applyTransformation(part, transform_type, p0, p1, p2, p3, t)
	local data
	if p1.int == "catmullrom" then
		data = catmullRomInterpolate(p0.pre, p1.pre, p2.pre, p3.pre, t)
	elseif p1.int == "bezier" then
		data = bezierInterpolate(p1.pre, p1.br, p2.bl, p2.pre, t)
	elseif p1.int == "step" then
		data = p1.pre
	else
		data = math.lerp(p1.pre, p2.pre, t)
	end

	if transform_type == "rot" then
		part:rot(data * vec(-1, -1, 1))
	elseif transform_type == "pos" then
		part:pos(data * vec(-1, 1, 1))
	elseif transform_type == "scl" then
		part:scale(data)
	end
end

---Renders this animation
---@return self
function class:render()
	local priv = self[1]

	if priv.state ~= "playing" then return self end

	local time = client.getSystemTime()
	local diff = time - priv.render
	priv.time = (priv.time + diff * priv.speed / 1000)
	priv.render = time

	if priv.time >= priv.len then
		local loop = priv.loop
		if loop == "once" then
			-- priv.time = 0
			-- self:stop()
			-- return self
			priv.time = priv.time % priv.len
		elseif loop == "hold" then
			priv.time = priv.len
			self:pause()
		elseif loop == "loop" then
			priv.time = priv.time % priv.len
		end
	end

	for mdl, data in pairs(priv.keys) do
		for type, frames in pairs(data) do
			local p0, p1, p2, p3 = findFrames(frames, priv.time)
			if p1 and p2 then
				local t = (p1.time == p2.time) and 0 or (priv.time - p1.time) / (p2.time - p1.time)
				self:applyTransformation(mdl, type, p0, p1, p2, p3, t)
			end
		end
	end

	return self
end

-- local ani = api.new(
-- 	deepCopy(models.Models.Player):moveTo(models):parentType("World"),
-- 	animations["Models.Player"].blink
-- ):play()

-- function events.render() ani:render() end

return api

--#ENDREGION
