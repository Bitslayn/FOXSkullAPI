--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Item Bakery v1.0.0-dev
]]

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

--#REGION Regions

---@type table<string, table>
local filled = {}

---@param tex Texture
---@param u integer
---@param v integer
---@param w integer
---@param h integer
---@return table
local function fillRegions(tex, u, v, w, h)
	---@diagnostic disable-next-line: undefined-field
	local key = table.concat({ tex:getPath(), u, v, w, h }, "-")
	if filled[key] then return filled[key] end

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

	pcall(tex.applyFunc, tex, u, v, w, h, function(col, x, y)
		x = x - u
		y = y - v
		if pos and col.a == 0 or (x < 1 and len > 0) then
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

		for k, val in pairs(a) do
			if b[k] and b[k].wid == val.wid then
				val.hei = val.hei + 1
				a[k] = nil
				b[k] = val
			end
		end

		::continue::
	end

	filled[key] = regions
	return regions
end

--#ENDREGION
--#REGION Extrusion

---@type table<string, ModelPart>
local extruded = {}

---Bakes a texture into an extruded model
---@param tex Texture
---@param u integer
---@param v integer
---@param w integer
---@param h integer
---@return ModelPart
local function bakeExtruded(tex, u, v, w, h)
	---@diagnostic disable-next-line: undefined-field
	local key = table.concat({ tex:getPath(), u, v, w, h }, "-")
	if extruded[key] then return extruded[key] end

	local regions = fillRegions(tex, u, v, w, h)

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
	---@diagnostic disable-next-line: undefined-field
	local key = table.concat({ tex:getPath(), u, v, w, h }, "-")
	if flat[key] then return flat[key] end

	local regions = fillRegions(tex, u, v, w, h)

	local model = models:newPart(tex:getName())
	local t_w, t_h = tex:getDimensions():unpack()

	local i = 0
	for _, tbl in pairs(regions) do
		for _, val in pairs(tbl) do
			local x, y, wid, hei = val.x, val.y, val.wid, val.hei
			i = i + 1

			model:newSprite("flat-" .. i)
				:pos(-x, -y, 1)
				:texture(tex, t_w, t_h)
				:uvPixels(x + u, y + v)
				:size(wid, hei)
				:region(wid, hei)
				:renderType("EMISSIVE_SOLID")
		end
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
local bakery = { poses = poses }

---@class FOXItemBakery.priv
---@field pose table<ItemTask.displayMode, FOXItemBakery.transform>
---@field offset table<ItemTask.displayMode, FOXItemBakery.transform>
---@field texture Texture?
---@field u integer?
---@field v integer?
---@field w integer?
---@field h integer?
---@field res integer?
---@field queue boolean?

---@class FOXItemBakery.item
---@field parts table<ItemTask.displayMode, ModelPart>
---@field package [1] FOXItemBakery.priv
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

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Class > New ♡˚
------------------------------------------------------------------------------------------------

---Takes a texture and returns a table of extruded item models of different display contexts
---@param tex Texture?
---@param pose FOXItemBakery.pose?
---@return FOXItemBakery.item?
function bakery.newItem(tex, pose)
	---@type FOXItemBakery.priv
	---@diagnostic disable-next-line: missing-fields
	local priv = {
		pose = {},
		offset = {},
	}
	local self = setmetatable({ parts = {}, [1] = priv }, class)

	self:setPose(pose)

	for k in pairs(priv.pose) do
		local itm = models:newPart(k)
		---@diagnostic disable-next-line: unused-local
		local pvt = itm:newPart("pvt")

		self.parts[k] = itm:visible(false)
	end

	if tex then
		self:setTexture(tex)
	end

	return self
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Class > Pose ♡˚
------------------------------------------------------------------------------------------------

---Sets this item's pose, resetting all custom transformations
---@param self FOXItemBakery.item
---@param pose FOXItemBakery.pose
---@return FOXItemBakery.item
local function setPose(self, pose)
	---@type FOXItemBakery.priv
	local priv = self[1]
	pose = pose and string.upper(pose) or "DEFAULT"

	---@type FOXItemBakery.transform
	priv.pose = {}
	for k, v in pairs(poses[pose]) do
		priv.pose[k] = {
			rotation = v.rotation,
			translation = v.translation,
			scale = v.scale,
		}
		if not priv.offset[k] then priv.offset[k] = {} end
	end

	return self:updateMatrices()
end

---Sets this item's pose, resetting all custom transformations
---@param pose FOXItemBakery.pose
---@return self
function class:pose(pose)
	return setPose(self, pose)
end

---Sets this item's pose, resetting all custom transformations
---@param pose FOXItemBakery.pose
---@return self
function class:setPose(pose)
	return setPose(self, pose)
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Class > Texture ♡˚
------------------------------------------------------------------------------------------------

--#REGION Texture

---Sets this item's uv
---@param self FOXItemBakery.item
---@param tex Texture
---@param w integer?
---@param h integer?
---@return FOXItemBakery.item
local function setTexture(self, tex, w, h)
	---@type FOXItemBakery.priv
	local priv = self[1]
	priv.texture = tex

	local _w, _h = priv.texture:getDimensions():unpack()
	priv.w, priv.h = w or _w, h or _h

	local res = 1 / (priv.h / 16)
	local changed = res ~= priv.res
	priv.res = res

	self:updateModel()

	return changed and self:updateMatrices() or self
end

---Sets this item's texture
---@param tex Texture
---@param w integer?
---@param h integer?
---@return self
function class:texture(tex, w, h)
	return setTexture(self, tex, w, h)
end

---Sets this item's texture
---@param tex Texture
---@param w integer?
---@param h integer?
---@return self
function class:setTexture(tex, w, h)
	return setTexture(self, tex, w, h)
end

---Returns this item's texture
---@return Texture?
function class:getTexture()
	return self[1].texture
end

--#ENDREGION
--#REGION UV

---Sets this item's uv
---@param self FOXItemBakery.item
---@param u integer?
---@param v integer?
---@return FOXItemBakery.item
local function setUV(self, u, v)
	---@type FOXItemBakery.priv
	local priv = self[1]
	u, v = u or 0, v or 0
	priv.u, priv.v = u, v

	self:updateModel()

	return self
end

---Sets this item's uv
---@param u integer?
---@param v integer?
---@return self
function class:uv(u, v)
	return setUV(self, u, v)
end

---Sets this item's uv
---@param u integer?
---@param v integer?
---@return self
function class:setUV(u, v)
	return setUV(self, u, v)
end

--#ENDREGION
--#REGION Animation

---Sets the current frame number
---
---Useful for animated textures
---@param self FOXItemBakery.item
---@param frame integer?
---@param vertical boolean?
---@return FOXItemBakery.item
local function setFrame(self, frame, vertical)
	---@type FOXItemBakery.priv
	local priv = self[1]
	frame = frame or 0

	local u, v, w, h = priv.u, priv.v, priv.w, priv.h
	local _u, _v = u or 0, v or 0

	local t_w, t_h = priv.texture:getDimensions():unpack()
	local f_w, f_h = t_w / w, t_h / h

	-- Add current uv position to frame number

	if vertical then
		frame = frame + (_u / w * f_h) + _v / h
	else
		frame = frame + (_v / h * f_w) + _u / w
	end

	-- Floor frame number, and loop frames after passing through bottom right sprite of image

	frame = frame - frame % 1 % (f_w * f_h)

	-- Calculate UV

	if vertical then
		_v = frame % f_h * h
		_u = math.floor(frame / f_h) * w
	else
		_u = frame % f_w * w
		_v = math.floor(frame / f_w) * h
	end

	setUV(self, _u, _v)
	priv.u, priv.v = u, v
	return self
end

---Sets the current frame number
---
---Useful for animated textures
---@param frame integer?
---@param vertical boolean?
---@return self
function class:frame(frame, vertical)
	return setFrame(self, frame, vertical)
end

---Sets the current frame number
---
---Useful for animated textures
---@param frame integer?
---@param vertical boolean?
---@return self
function class:setFrame(frame, vertical)
	return setFrame(self, frame, vertical)
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Class > Transform ♡˚
------------------------------------------------------------------------------------------------

---@param t table
---@param k any
---@param v any
---@param m ItemTask.displayMode
local function distribute(t, k, v, m)
	local changed

	if m then
		m = string.upper(m)
		changed = changed or t[m][k] ~= v
		t[m][k] = v
	else
		for _, _t in pairs(t) do
			changed = changed or _t[k] ~= v
			_t[k] = v
		end
	end

	return changed
end

---@param ... any
---@return Vector3, string
local function pack(...)
	local p = { ... }
	if type(p[1]) == "Vector3" then
		return p[1], p[2]
	else
		return vec(table.unpack(p, 1, 3)) --[[@as Vector3]], p[4]
	end
end

--#REGION Rot

---Sets this item's rotation
---@param rot Vector3
---@param mode ItemTask.displayMode
---@return self
function class:rot(rot, mode)
	return distribute(self[1].pose, "rotation", pack(rot, mode)) and self:updateMatrices() or self
end

---Sets this item's rotation
---@param x number
---@param y number
---@param z number
---@param mode ItemTask.displayMode
---@return self
function class:rot(x, y, z, mode)
	return distribute(self[1].pose, "rotation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Sets this item's rotation
---@param rot Vector3
---@param mode ItemTask.displayMode
---@return self
function class:setRot(rot, mode)
	return distribute(self[1].pose, "rotation", pack(rot, mode)) and self:updateMatrices() or self
end

---Sets this item's rotation
---@param x number
---@param y number
---@param z number
---@param mode ItemTask.displayMode
---@return self
function class:setRot(x, y, z, mode)
	return distribute(self[1].pose, "rotation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Gets this item's current rotation
---@param mode ItemTask.displayMode
---@return Vector3
function class:getRot(mode)
	mode = mode and string.upper(mode)
	return self[1].pose[mode].rotation
end

---Sets this item's offset rotation
---@param rot Vector3
---@param mode ItemTask.displayMode
---@return self
function class:rot(rot, mode)
	return distribute(self[1].offset, "rotation", pack(rot, mode)) and self:updateMatrices() or self
end

---Sets this item's offset rotation
---@param x number
---@param y number
---@param z number
---@param mode ItemTask.displayMode
---@return self
function class:rot(x, y, z, mode)
	return distribute(self[1].offset, "rotation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Sets this item's offset rotation
---@param rot Vector3
---@param mode ItemTask.displayMode
---@return self
function class:setRot(rot, mode)
	return distribute(self[1].offset, "rotation", pack(rot, mode)) and self:updateMatrices() or self
end

---Sets this item's offset rotation
---@param x number
---@param y number
---@param z number
---@param mode ItemTask.displayMode
---@return self
function class:setRot(x, y, z, mode)
	return distribute(self[1].offset, "rotation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Gets this item's current offset rotation
---@param mode ItemTask.displayMode
---@return Vector3
function class:getOffsetRot(mode)
	mode = mode and string.upper(mode)
	return self[1].offset[mode].rotation
end

--#ENDREGION
--#REGION Pos

---Sets this item's position
---@param pos Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:pos(pos, mode)
	return distribute(self[1].pose, "translation", pack(pos, mode)) and self:updateMatrices() or self
end

---Sets this item's position
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:pos(x, y, z, mode)
	return distribute(self[1].pose, "translation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Sets this item's position
---@param pos Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:setPos(pos, mode)
	return distribute(self[1].pose, "translation", pack(pos, mode)) and self:updateMatrices() or self
end

---Sets this item's position
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:setPos(x, y, z, mode)
	return distribute(self[1].pose, "translation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Gets this item's current position
---@param mode ItemTask.displayMode
---@return Vector3
function class:getPos(mode)
	mode = mode and string.upper(mode)
	return self[1].pose[mode].translation
end

---Sets this item's offset position
---@param pos Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:offsetPos(pos, mode)
	return distribute(self[1].offset, "translation", pack(pos, mode)) and self:updateMatrices() or self
end

---Sets this item's offset position
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:offsetPos(x, y, z, mode)
	return distribute(self[1].offset, "translation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Sets this item's offset position
---@param pos Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:setOffsetPos(pos, mode)
	return distribute(self[1].offset, "translation", pack(pos, mode)) and self:updateMatrices() or self
end

---Sets this item's offset position
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:setOffsetPos(x, y, z, mode)
	return distribute(self[1].offset, "translation", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Gets this item's current offset position
---@param mode ItemTask.displayMode
---@return Vector3
function class:getOffsetPos(mode)
	mode = mode and string.upper(mode)
	return self[1].offset[mode].translation
end

--#ENDREGION
--#REGION Scale

---Sets this item's scale
---@param scale Vector3?
---@param mode ItemTask.displayMode
---@return self
function class:scale(scale, mode)
	return distribute(self[1].pose, "scale", pack(scale, mode)) and self:updateMatrices() or self
end

---Sets this item's scale
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:scale(x, y, z, mode)
	return distribute(self[1].pose, "scale", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Sets this item's scale
---@param scale Vector3?
---@param mode ItemTask.displayMode
---@return self
function class:setScale(scale, mode)
	return distribute(self[1].pose, "scale", pack(scale, mode)) and self:updateMatrices() or self
end

---Sets this item's scale
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:setScale(x, y, z, mode)
	return distribute(self[1].pose, "scale", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Gets this item's current scale
---@param mode ItemTask.displayMode
---@return Vector3
function class:getScale(mode)
	mode = mode and string.upper(mode)
	return self[1].pose[mode].scale
end

---Sets this item's offset scale
---@param scale Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:offsetScale(scale, mode)
	return distribute(self[1].offset, "scale", pack(scale, mode)) and self:updateMatrices() or self
end

---Sets this item's offset scale
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:offsetScale(x, y, z, mode)
	return distribute(self[1].offset, "scale", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Sets this item's offset scale
---@param scale Vector3?
---@param mode ItemTask.displayMode?
---@return self
function class:setOffsetScale(scale, mode)
	return distribute(self[1].offset, "scale", pack(scale, mode)) and self:updateMatrices() or self
end

---Sets this item's offset scale
---@param x number?
---@param y number?
---@param z number?
---@param mode ItemTask.displayMode?
---@return self
function class:setOffsetScale(x, y, z, mode)
	return distribute(self[1].offset, "scale", pack(x, y, z, mode)) and self:updateMatrices() or self
end

---Gets this item's current offset scale
---@param mode ItemTask.displayMode
---@return Vector3
function class:getOffsetScale(mode)
	mode = mode and string.upper(mode)
	return self[1].offset[mode].scale
end

--#ENDREGION

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Class > Matrices ♡˚
------------------------------------------------------------------------------------------------

local zeroVec, oneVec = vectors.vec3(), vectors.vec3() + 1

---Update's this item's matrices
---@return self
function class:updateMatrices()
	---@type FOXItemBakery.priv
	local priv = self[1]
	for mode, mdp in pairs(self.parts) do
		mdp.pvt.preRender = function(_, _, part)
			local pose = priv.pose[mode]
			local offset = priv.offset[mode]

			local pos = (pose.translation or zeroVec) + (offset.translation or zeroVec)
			local rot = (pose.rotation or zeroVec) + (offset.rotation or zeroVec)
			local scl = (pose.scale or oneVec) * (offset.scale or oneVec)

			local mat = matrices.mat4()
				:translate(priv.w / 2, priv.h / 2, -0.5)
				:scale(priv.res, priv.res, 1)
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
--#REGION ˚♡ Class > Model ♡˚
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

---Update's this item's model
---@return self
function class:updateModel()
	---@type FOXItemBakery.priv
	local priv = self[1]
	if not priv.texture then return self end

	local u, v, w, h = priv.u or 0, priv.v or 0, priv.w, priv.h

	local _extruded = bakeExtruded(priv.texture, u, v, w, h):visible(true)
	local _flat = bakeFlat(priv.texture, u, v, w, h):visible(true)

	for k in pairs(priv.pose) do
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

	return self
end

---Returns the item model of the given mode
---@param mode ItemTask.displayMode
---@return ModelPart
function class:getModel(mode)
	mode = mode and string.upper(mode)
	return self.parts[mode]
end

--#ENDREGION

return bakery

--#ENDREGION
