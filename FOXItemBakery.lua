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
---@return ModelPart
local function bakeExtruded(tex)
	local regions = {}
	local w, h = tex:getDimensions():unpack()

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

	tex:applyFunc(nil, nil, w, h, function(col, x, y)
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

		for k, v in pairs(a) do
			if b[k] and b[k].wid == v.wid then
				v.hei = v.hei + 1
				a[k] = nil
				b[k] = v
			end
		end

		::continue::
	end

	local model = models:newPart(tex:getName())

	local i = 0
	for _, tbl in pairs(regions) do
		for _, v in pairs(tbl) do
			local x, y, wid, hei = v.x, v.y, v.wid, v.hei
			i = i + 1

			model:newSprite("up-" .. i)
				:pos(-x, -y, 1)
				:rot(-90, -180, -180)
				:texture(tex, w, h)
				:uvPixels(x, y)
				:size(wid, 1)
				:region(wid, 1)
				:renderType("TRANSLUCENT_CULL")

			model:newSprite("down-" .. i)
				:pos(-x, -y - hei, 0)
				:rot(-90, 0, 0)
				:texture(tex, w, h)
				:uvPixels(x, y + hei - 1)
				:size(wid, 1)
				:region(wid, 1)
				:renderType("TRANSLUCENT_CULL")

			model:newSprite("east-" .. i)
				:pos(-x, -y, 1)
				:rot(0, -90, 0)
				:texture(tex, w, h)
				:uvPixels(x, y)
				:size(1, hei)
				:region(1, hei)
				:renderType("TRANSLUCENT_CULL")

			model:newSprite("west-" .. i)
				:pos(-x - wid, -y, 0)
				:rot(0, 90, 0)
				:texture(tex, w, h)
				:uvPixels(x + wid - 1, y)
				:size(1, hei)
				:region(1, hei)
				:renderType("TRANSLUCENT_CULL")
		end
	end

	model:newSprite("north")
		:texture(tex, w, h)
		:size(w, h)
		:region(w, h)
		:renderType("TRANSLUCENT_CULL")

	model:newSprite("south")
		:pos(-w, 0, 1)
		:rot(0, 180, 0)
		:texture(tex, w, h)
		:size(w, h)
		:region(-w, h)
		:renderType("TRANSLUCENT_CULL")

	extruded[tex] = model
	return extruded[tex]
end

---Returns the extruded model from cache, or bakes this model
---@param tex any
---@return ModelPart
local function getExtruded(tex)
	return extruded[tex] or bakeExtruded(tex)
end

--#ENDREGION
--#REGION Flat

---@type table<Texture, ModelPart>
local flat = {}

---Bakes a texture into a flat model
---@param tex Texture
---@return ModelPart
local function bakeFlat(tex)
	local w, h = tex:getDimensions():unpack()

	local model = models:newPart(tex:getName())

	local sprite = model:newSprite("north")
		:texture(tex, w, h)
		:size(w, h)
		:region(w, h)
		:renderType("TRANSLUCENT_CULL")

	for _, vert in pairs(sprite:getVertices()) do
		vert:setNormal(0, -1, 0)
	end

	flat[tex] = model
	return flat[tex]
end

---Returns the flat model from cache, or bakes this model
---@param tex any
---@return ModelPart
local function getFlat(tex)
	return flat[tex] or bakeFlat(tex)
end

--#ENDREGION

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Class ♡˚
--==============================================================================================================================

---@class FOXItemBakery
local bakery = {}

---@type FOXItemBakery.item[]
local queue = {}

function events.world_render()
	for _, self in pairs(queue) do
		self.queue = nil

		local w, h = self.texture:getDimensions():unpack()
		local res = 1 / (h / 16)

		for k, v in pairs(self.pose) do
			local pos = v.translation or vectors.vec3()
			local rot = v.rotation or vectors.vec3()
			local scl = v.scale or vectors.vec3() + 1

			local mat = matrices.mat4()
				:translate(w / 2, h / 2, -0.5)
				:scale(res, res, 1)
				:scale(scl)
				:rotateZ(rot.x)
				:rotateY(rot.y)
				:rotateX(rot.z)
				:translate(pos:copy():mul(-1, 1, -1))
				:multiply(mats[k])

			self.parts[k].item:matrix(mat)
		end
	end
end

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

---@class FOXItemBakery.item
---@field parts table<ItemTask.displayMode, ModelPart>
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

---Update's this item's matrices
---@return self
function class:updateMatrices()
	if not self.queue then
		self.queue = true
		table.insert(queue, self)
	end
	return self
end

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
	end

	return self:updateMatrices()
end

---Sets this item's UV
---@param tex Texture
---@param u integer?
---@param v integer?
---@param w integer?
---@param h integer?
---@return self
function class:setUV(tex, u, v, w, h)
	self.texture = tex

	local _extruded = getExtruded(tex):visible(true)
	local _flat = getFlat(tex):visible(true)

	for k in pairs(self.pose) do
		local model = k ~= "GUI" and _extruded or _flat

		local pivot = models:newPart(tex:getName())
		local item = model:copy("item"):moveTo(pivot)

		if not next(item:getTask()) then
			copyTasks(model, item)
		end

		self.parts[k] = pivot:visible(false)
	end

	_extruded:visible(false)
	_flat:visible(false)

	return self:updateMatrices()
end

---Sets this item's rotation
---@param rotation Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:rot(rotation, mode)
	if mode then
		mode = string.upper(mode)
		self.pose[mode].rotation = rotation
	else
		for _, pose in pairs(self.pose) do
			pose.rotation = rotation
		end
	end
	return self:updateMatrices()
end

---Gets this item's current rotation
---@param mode ItemTask.displayMode?
---@return Vector3
function class:getRot(mode)
	mode = mode and string.upper(mode)
	return self.pose[mode].rotation
end

---Takes a texture and returns a table of extruded item models of different display contexts
---@param tex Texture
---@param pose FOXItemBakery.pose?
---@return FOXItemBakery.item?
function bakery.newItem(tex, pose)
	local self = setmetatable({ parts = {} }, class)

	if not tex then return end
	self:setPose(pose)
		:setUV(tex)

	return self
end

return bakery

--#ENDREGION
