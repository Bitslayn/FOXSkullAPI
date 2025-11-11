--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Item Bakery v1.0.0-dev
]]

-- THIS WORKS BUT THERE IS A MODELPART LEAK
-- I WILL REWRITE THE MODELPARTS SO THAT THEY ARE TAKEN BY THE SKULL API IN A MORE PREDICTABLE WAY SOON

--==============================================================================================================================
--#REGION ˚♡ Bakery ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Bakery > Enums ♡˚
------------------------------------------------------------------------------------------------

---@alias FOXItemBakery.pose
---| "DEFAULT"
---| "HANDHELD"

---@class FOXItemBakery.transform
---@field rotation Vector3?
---@field translation Vector3?
---@field scale Vector3?

---@alias FOXItemBakery.poses {[FOXItemBakery.pose]: {[ItemTask.displayMode]: FOXItemBakery.transform}}
---@type FOXItemBakery.poses
local poses = {
	DEFAULT = {
		FIRST_PERSON_LEFT_HAND = {
			rotation = vec(0, 90, 25),
			translation = vec(-1.13, 3.2, 1.13),
			scale = vec(0.68, 0.68, 0.68),
		},
		FIRST_PERSON_RIGHT_HAND = {
			rotation = vec(0, -90, 25),
			translation = vec(1.13, 3.2, 1.13),
			scale = vec(0.68, 0.68, 0.68),
		},
		THIRD_PERSON_LEFT_HAND = {
			translation = vec(0, 3, 1),
			scale = vec(0.55, 0.55, 0.55),
		},
		THIRD_PERSON_RIGHT_HAND = {
			translation = vec(0, 3, 1),
			scale = vec(0.55, 0.55, 0.55),
		},
		HEAD = {
			rotation = vec(0, 180, 0),
			translation = vec(0, 13, 7),
		},
		GUI = {},
		GROUND = {
			translation = vec(0, 2, 0),
			scale = vec(0.5, 0.5, 0.5),
		},
		FIXED = {
			rotation = vec(0, 180, 0),
		},
	},
	HANDHELD = {
		FIRST_PERSON_LEFT_HAND = {
			rotation = vec(0, -90, 25),
			translation = vec(-1.13, 3.2, 1.13),
			scale = vec(0.68, 0.68, 0.68),
		},
		FIRST_PERSON_RIGHT_HAND = {
			rotation = vec(0, -90, 25),
			translation = vec(1.13, 3.2, 1.13),
			scale = vec(0.68, 0.68, 0.68),
		},
		THIRD_PERSON_LEFT_HAND = {
			rotation = vec(0, -90, 55),
			translation = vec(0, 4, 0.5),
			scale = vec(0.85, 0.85, 0.85),
		},
		THIRD_PERSON_RIGHT_HAND = {
			rotation = vec(0, -90, 55),
			translation = vec(0, 4, 0.5),
			scale = vec(0.85, 0.85, 0.85),
		},
		HEAD = {
			rotation = vec(0, 180, 0),
			translation = vec(0, 13, 7),
		},
		GUI = {},
		GROUND = {
			translation = vec(0, 2, 0),
			scale = vec(0.5, 0.5, 0.5),
		},
		FIXED = {
			rotation = vec(0, 180, 0),
		},
	},
}

---Stores all the item transformation matrices for undoing block model transformations
---@alias FOXItemBakery.matrices {[ItemTask.displayMode]: Matrix4}
---@type FOXItemBakery.matrices
local mats = {
	FIRST_PERSON_LEFT_HAND = matrices.mat4()
		:translate(0, 8, 0),
	FIRST_PERSON_RIGHT_HAND = matrices.mat4()
		:translate(0, 8, 0),
	THIRD_PERSON_LEFT_HAND = matrices.mat4()
		:translate(0, -3, 0)
		:rotateX(90)
		:rotate(-45, -45, 0)
		:rotateY(90)
		:translate(0, 4, 0)
		:scale(2),
	THIRD_PERSON_RIGHT_HAND = matrices.mat4()
		:translate(0, -3, 0)
		:rotate(45, 45, 0)
		:rotateY(-90)
		:translate(0, 4, 0)
		:scale(2),
	HEAD = matrices.mat4()
		:translate(0, 6.4, 0)
		:rotateY(180)
		:scale(0.526),
	GUI = matrices.mat4()
		:translate(0, 4, 0)
		:rotate(30, -45, 0),
	GROUND = matrices.mat4()
		:translate(0, 3, 0)
		:scale(2),
	FIXED = matrices.mat4()
		:translate(0, 4, 0)
		:rotateY(180),
}

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Bakery > Bake ♡˚
------------------------------------------------------------------------------------------------

--#REGION Extrusion

---@type table<Texture, ModelPart>
local extruded = {}

---Bakes a texture into an extruded model
---@param tex Texture
---@param u integer
---@param v integer
---@param w integer
---@param h integer
---@return ModelPart
local function bakeExtruded(tex, u, v, w, h)
	local key = table.concat({ tex:getName(), u, v, w, h }, "-")
	if extruded[key] then return extruded[key] end

	local regions = {}

	local pos
	local len = 0

	---Add current region
	---@param x number
	---@param y number
	local function push(x, y)
		if not regions[y] then regions[y] = {} end
		regions[y][x] = { x = pos.x, y = pos.y, wid = len, hei = 1 }
	end

	-- Expand regions horizontally

	tex:applyFunc(u, v, w, h, function(col, x, y)
		x = x - u
		y = y - v
		if pos and col.a == 0 or (x == 0 and len > 0) then
			push(x, y)

			pos = nil
			len = 0
		end

		if col.a == 0 then return end
		if not pos then pos = vec(x, y) end
		len = len + 1
	end)
	if len > 0 then push(w - len, h) end

	-- Expand regions vertically

	for i = 1, h do
		local a, b = regions[i - 1], regions[i]
		if not (a and b) then goto continue end

		for key, val in pairs(a) do
			if b[key] and b[key].wid == val.wid then
				val.hei = val.hei + 1
				a[key] = nil
				b[key] = val
			end
		end

		::continue::
	end

	local model = models:newPart(tex:getName())
	local t_w, t_h = tex:getDimensions():unpack()

	local i = 0
	for _, tbl in pairs(regions) do
		for _, val in pairs(tbl) do
			local x, y, wid, hei = val.x, val.y, val.wid, val.hei
			i = i + 1

			model:newSprite("up-" .. i)
				:pos(-x, -y, 1)
				:rot(-90, -180, -180)
				:texture(tex, t_w, t_h)
				:uvPixels(x + u, y + v)
				:size(wid, 1)
				:region(wid, 1)
				:renderType("TRANSLUCENT_CULL")

			model:newSprite("down-" .. i)
				:pos(-x, -y - hei, 0)
				:rot(-90, 0, 0)
				:texture(tex, t_w, t_h)
				:uvPixels(x + u, y + hei - 1 + v)
				:size(wid, 1)
				:region(wid, 1)
				:renderType("TRANSLUCENT_CULL")

			model:newSprite("east-" .. i)
				:pos(-x, -y, 1)
				:rot(0, -90, 0)
				:texture(tex, t_w, t_h)
				:uvPixels(x + u, y + v)
				:size(1, hei)
				:region(1, hei)
				:renderType("TRANSLUCENT_CULL")

			model:newSprite("west-" .. i)
				:pos(-x - wid, -y, 0)
				:rot(0, 90, 0)
				:texture(tex, t_w, t_h)
				:uvPixels(x + wid - 1 + u, y + v)
				:size(1, hei)
				:region(1, hei)
				:renderType("TRANSLUCENT_CULL")
		end
	end

	model:newSprite("north")
		:texture(tex, t_w, t_h)
		:uvPixels(u, v)
		:size(w, h)
		:region(w, h)
		:renderType("TRANSLUCENT_CULL")

	model:newSprite("south")
		:pos(-w, 0, 1)
		:rot(0, 180, 0)
		:texture(tex, t_w, t_h)
		:uvPixels(w - t_w + u, v)
		:size(w, h)
		:region(-w, h)
		:renderType("TRANSLUCENT_CULL")

	extruded[key] = model
	return extruded[key]
end

--#ENDREGION
--#REGION Flat

---@type table<string, ModelPart>
local flat = {}

---Bakes a texture into a flat model
---@param tex Texture
---@param u integer
---@param v integer
---@param w integer
---@param h integer
---@return ModelPart
local function bakeFlat(tex, u, v, w, h)
	local key = table.concat({ tex:getName(), u, v, w, h }, "-")
	if flat[key] then return flat[key] end

	local model = models:newPart(tex:getName())
	local t_w, t_h = tex:getDimensions():unpack()

	local sprite = model:newSprite("north")
		:texture(tex, t_w, t_h)
		:uvPixels(u, v)
		:size(w, h)
		:region(w, h)

	for _, vert in pairs(sprite:getVertices()) do
		vert:setNormal(0, -1, 0)
	end

	flat[key] = model
	return flat[key]
end

--#ENDREGION

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Class ♡˚
--==============================================================================================================================

---@class FOXItemBakery
local bakery = {}

---@class FOXItemBakery.item
---@field parts table<ItemTask.displayMode, ModelPart>
---@field pose table<ItemTask.displayMode, FOXItemBakery.transform>
---@field offset table<ItemTask.displayMode, FOXItemBakery.transform>
---@field texture Texture
---@field u integer
---@field v integer
---@field w integer
---@field h integer
---@field res integer
---@field queue boolean?
local class = {
	["FOXSkull$model"] = "parts",
	["FOXSkull$contexts"] = {
		BLOCK = "FIXED",
		OTHER = "GUI",
		FIRST_PERSON_LEFT_HAND = "FIRST_PERSON_LEFT_HAND",
		FIRST_PERSON_RIGHT_HAND = "FIRST_PERSON_RIGHT_HAND",
		THIRD_PERSON_LEFT_HAND = "THIRD_PERSON_LEFT_HAND",
		THIRD_PERSON_RIGHT_HAND = "THIRD_PERSON_RIGHT_HAND",
		HEAD = "HEAD",
		GUI = "GUI",
		GROUND = "GROUND",
		FIXED = "FIXED",
	},
}
class.__index = class

---Takes a texture and returns a table of extruded item models of different display contexts
---@param tex Texture?
---@param pose FOXItemBakery.pose?
---@return FOXItemBakery.item?
function bakery.newItem(tex, pose)
	local self = setmetatable({
		parts = {},
		offset = {},
	}, class)

	self:setPose(pose)

	for k in pairs(self.pose) do
		local itm = models:newPart(k)
		---@diagnostic disable-next-line: unused-local
		local pvt = itm:newPart("pvt")

		self.parts[k] = itm:visible(false)
	end

	if tex then
		self:setUV(tex)
	end

	return self
end

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Class > Update Matrices ♡˚
------------------------------------------------------------------------------------------------

local zeroVec = vectors.vec3()

---Update's this item's matrices
---@return self
function class:updateMatrices()
	for mode, mdp in pairs(self.parts) do
		mdp.pvt.preRender = function(_, _, part)
			local pose = self.pose[mode]
			local offset = self.offset[mode]
			
			local pos = (pose.translation or zeroVec) + (offset.translation or zeroVec + 1)
			local rot = (pose.rotation or zeroVec) + (offset.rotation or zeroVec)
			local scl = (pose.scale or zeroVec + 1) * (offset.scale or zeroVec + 1)

			local mat = matrices.mat4()
				:translate(self.w / 2, self.h / 2, -0.5)
				:scale(self.res, self.res, 1)
				:scale(scl)
				:rotateZ(rot.x)
				:rotateY(rot.y)
				:rotateX(rot.z)
				:translate(pos:copy():mul(-1, 1, -1))
				:multiply(mats[mode])

			part:matrix(mat)
			part.preRender = nil
		end
	end

	return self
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Class > Pose ♡˚
------------------------------------------------------------------------------------------------

---Sets this item's pose, resetting all custom transformations
---@param pose FOXItemBakery.pose
---@return self
function class:setPose(pose)
	pose = pose and string.upper(pose) or "DEFAULT"

	---@type FOXItemBakery.transform
	self.pose = {}
	for k, v in pairs(poses[pose]) do
		self.pose[k] = {
			rotation = v.rotation,
			translation = v.translation,
			scale = v.scale,
		}
		if not self.offset[k] then self.offset[k] = {} end
	end

	return self:updateMatrices()
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Class > UV ♡˚
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

---Sets this item's uv
---@param self FOXItemBakery.item
---@param tex Texture
---@param u integer?
---@param v integer?
---@param w integer?
---@param h integer?
---@return FOXItemBakery.item
local function setUV(self, tex, u, v, w, h)
	self.texture = tex
	if not (w and h) then
		w, h = tex:getDimensions():unpack()
	end
	u, v = u or 0, v or 0
	self.u, self.v, self.w, self.h = u, v, w, h

	local res = 1 / (h / 16)
	local resChanged = res ~= self.res
	self.res = res

	local _extruded = bakeExtruded(tex, u, v, w, h):visible(true)
	local _flat = bakeFlat(tex, u, v, w, h):visible(true)

	for k in pairs(self.pose) do
		local model = k ~= "GUI" and _extruded or _flat

		local pvt = self.parts[k].pvt
		if pvt.tsk then pvt.tsk:remove() end
		local tsk = model:copy("tsk"):moveTo(pvt)

		if not next(tsk:getTask()) then
			copyTasks(model, tsk)
		end
	end

	_extruded:visible(false)
	_flat:visible(false)

	return resChanged and self:updateMatrices() or self
end

---Sets this item's UV
---@param tex Texture
---@param u integer?
---@param v integer?
---@param w integer?
---@param h integer?
---@return self
function class:setUV(tex, u, v, w, h)
	return setUV(self, tex, u, v, w, h)
end

---comment
---@param frame integer?
---@return self
function class:setFrame(frame)
	local u, v = self.u, self.v
	setUV(self, self.texture, frame * self.w + u, v, self.w, self.h)
	self.u, self.v = u, v
	return self
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Class > Rot ♡˚
------------------------------------------------------------------------------------------------

---comment
---@param t table
---@param k any
---@param v any
---@param m ItemTask.displayMode
local function distribute(t, k, v, m)
	if m then
		m = string.upper(m)
		if not t[m] then t[m] = {} end
		t[m][k] = v
	else
		for _, _t in pairs(t) do
			_t[k] = v
		end
	end
end

---Sets this item's rotation
---@param rotation Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:rot(rotation, mode)
	distribute(self.pose, "rotation", rotation, mode)
	return self:updateMatrices()
end

---Gets this item's current rotation
---@param mode ItemTask.displayMode
---@return Vector3
function class:getRot(mode)
	mode = mode and string.upper(mode)
	return self.pose[mode].rotation
end

---Sets this item's offset rotation
---@param rotation Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:offsetRot(rotation, mode)
	distribute(self.offset, "rotation", rotation, mode)
	return self:updateMatrices()
end

---Gets this item's current offset rotation
---@param mode ItemTask.displayMode
---@return Vector3
function class:getOffsetRot(mode)
	mode = mode and string.upper(mode)
	return self.offset[mode].rotation
end

--#ENDREGION

return bakery

--#ENDREGION
