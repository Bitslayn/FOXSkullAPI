---@meta FOXSkull

---@type table<Texture, ModelPart>
local baked = {}

---@alias FOXSkullAPI.Enums.ItemPose
---| "DEFAULT"
---| "HANDHELD"
---| "NONE"

---@class FOXSkullAPI.ItemBakery
local bakery = {
	poses = {
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
			BLOCK = {
				translation = vec(0, 0, 0),
			},
			HEAD = {
				rotation = vec(0, 180, 0),
				translation = vec(0, 13, 7),
			},
			ITEM_ENTITY = {
				translation = vec(0, 2, 0),
				scale = vec(0.5, 0.5, 0.5),
			},
			ITEM_FRAME = {
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
			BLOCK = {
				translation = vec(0, 0, 0),
			},
			HEAD = {
				rotation = vec(0, 180, 0),
				translation = vec(0, 13, 7),
			},
			ITEM_ENTITY = {
				translation = vec(0, 2, 0),
				scale = vec(0.5, 0.5, 0.5),
			},
			ITEM_FRAME = {
				rotation = vec(0, 180, 0),
			},
		},
	},

	matrices = {
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
		BLOCK = matrices.mat4()
			:translate(0, 8, 0),
		HEAD = matrices.mat4()
			:translate(0, 6.4, 0)
			:rotateY(180)
			:scale(0.526),
		ITEM_ENTITY = matrices.mat4()
			:translate(0, 3, 0)
			:scale(2),
		ITEM_FRAME = matrices.mat4()
			:translate(0, 4, 0)
			:rotateY(180),
	},
}

---@param tex Texture
---@return ModelPart
local function extrudeTexture(tex)
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
	if len > 0 then
		push(w, h)
	end

	-- Expand regions vertically

	for i = 1, h do
		local a, b = regions[i - 1], regions[i]
		if a and b then
			for k, v in pairs(a) do
				if b[k] and b[k].wid == v.wid then
					v.hei = v.hei + 1
					a[k] = nil
					b[k] = v
				end
			end
		end
	end

	local model = models:newPart(tex:getName() .. "-extrude")
		:visible(false)
		:pos(w / 2, h / 2, -0.5)

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
				:renderType("CUTOUT_CULL")

			model:newSprite("down-" .. i)
				:pos(-x, -y - hei, 0)
				:rot(-90, 0, 0)
				:texture(tex, w, h)
				:uvPixels(x, y + hei - 1)
				:size(wid, 1)
				:region(wid, 1)
				:renderType("CUTOUT_CULL")

			model:newSprite("east-" .. i)
				:pos(-x, -y, 1)
				:rot(0, -90, 0)
				:texture(tex, w, h)
				:uvPixels(x, y)
				:size(1, hei)
				:region(1, hei)
				:renderType("CUTOUT_CULL")

			model:newSprite("west-" .. i)
				:pos(-x - wid, -y, 0)
				:rot(0, 90, 0)
				:texture(tex, w, h)
				:uvPixels(x + wid - 1, y)
				:size(1, hei)
				:region(1, hei)
				:renderType("CUTOUT_CULL")
		end
	end

	model:newSprite("north")
		:texture(tex, w, h)
		:size(w, h)
		:region(w, h)
		:renderType("CUTOUT_CULL")

	model:newSprite("south")
		:pos(-w, 0, 1)
		:rot(0, 180, 0)
		:texture(tex, w, h)
		:size(w, h)
		:region(-w, h)
		:renderType("CUTOUT_CULL")

	baked[tex] = model
	return model
end

function bakery.getModel(tex)
	return baked[tex] or extrudeTexture(tex)
end

return bakery
