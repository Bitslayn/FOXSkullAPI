---@meta FOXSkull

---@class FOXSkull.any
local anyClass = require("../../core/FOXSkull").class

---@type FOXSkullAPI.ItemBakery
local bakery = require("../../util/ItemBakery")

local mats = bakery.matrices
local poses = bakery.poses

---Sets the extruded texture to render for this skull
---@generic self
---@param self self
---@param tex Texture?
---@param pose FOXSkullAPI.Enums.ItemPose?
---@return self
function anyClass:setTexture(tex, pose)
	---@class FOXSkull.any.private
	local priv = self[1]

	priv.flatModel = nil
	priv.bakedModel = nil

	priv.texture = tex
	if not tex then return self end

	local w, h = tex:getDimensions():unpack()
	priv.res = 1 / (tex:getDimensions()[2] / 16)

	local pvt = tex:getDimensions():mul(0.5, 0.5).xy:augmented(-0.5)

	-- Flat 2D item

	priv.flatModel = models:newPart(tex:getName(), "Skull")
		:pos(0, 4.5, 0)
		:rot(35, -45, 0)
		:scale(priv.res)
		:visible(false)

	local sprite = priv.flatModel:newSprite("north")
		:pos(pvt)
		:texture(tex, w, h)
		:size(w, h)
		:region(w, h)
		:renderType("TRANSLUCENT_CULL")

	for _, vert in pairs(sprite:getVertices()) do
		vert:setNormal(0, -1, 0)
	end

	-- Baked 3D item

	local bakedModel = bakery.getModel(tex)
	local name = bakedModel:getName()

	priv.bakedPivot = models:newPart(name):parentType("Skull")
	priv.bakedModel = bakedModel:copy("bakedModel"):moveTo(priv.bakedPivot)

	if not priv.bakedModel:getTask("up-1") then -- Figura <0.1.6
		tex = textures:fromVanilla("errMissing", "textures/block/stone.png")
		priv.bakedModel = bakery.getModel(tex):moveTo(priv.bakedPivot)
		textures:fromVanilla("errMissing", "textures/block/stone.png")

		priv.res = 1
		pvt = vec(8, 8, -0.5)
	end

	pose = pose and string.upper(pose) or "DEFAULT"

	---@type {[string]: Matrix4}
	priv.itemMats = {}
	for key, mat in pairs(mats) do
		local curr = poses[pose] and poses[pose][key]
		local pos = curr and curr.translation or vec(0, 0, 0)
		local rot = curr and curr.rotation or vec(0, 0, 0)
		local scale = curr and curr.scale or vec(1, 1, 1)

		priv.itemMats[key] = matrices.mat4()
			:scale(priv.res, priv.res, 1)
			:scale(scale)
			:rotateZ(rot.x)
			:rotateY(rot.y)
			:rotateX(rot.z)
			:translate(pos:copy():mul(-1, 1, -1))
			:multiply(mat)
	end

	return self
end

---Sets the extruded texture to render for this skull
---@generic self
---@param self self
---@param tex Texture?
---@param pose FOXSkullAPI.Enums.ItemPose?
---@return self
function anyClass:texture(tex, pose)
	return self --[[@as FOXSkull.any]]:setTexture(tex, pose)
end

---Gets the extruded texture set to render for this skull
---@return Texture
---@nodiscard
function anyClass:getTexture()
	return self[1].texture
end
