local blank = textures:newTexture("", 1, 1)

local mat = matrices.mat4()
mat.c4 = vec(0, 0.5, 0, 0.125)

---@param color Vector3|Vector4?
---@param icon string?
---@return ModelPart
local function newOutline(color, icon)
	local outline = models:newPart("skullOutline", "Skull")
		:visible(false)
		:matrix(mat)

	for axis = 0, 2 do
		for rot = 0, 3 do
			local turn = math.floor(axis / 2)
			local lineMat = matrices.mat4()
				-- Create tube (Translates and rotates to form sides of tube)
				:translate(0.5, 0, -0.5)
				:rotate(0, rot * 90)

				-- Overlap tubes
				:translate(turn * -0.5, axis * 0.5 - turn * 0.5, axis * 0.5 - turn)
				-- Rotate horizontal tubes
				:rotate(axis * 90, 0, turn * 90)
				-- Uniform transform entire outline (This is done since the outline would currently be inside the floor)
				:translate(0, 0.5)

			outline:newSprite(axis .. rot)
				:setTexture(blank)
				:size(1, 1)
				:matrix(lineMat)
				:renderType("LINES")
				:color(color)
		end
	end

	local text = outline:newPart("text", "Camera")
	local pvt = text:newPart("pvt"):matrix(mat)
	pvt:newText("icon")
		:pos(0, -0.25, 0)
		:scale(1 / 16)
		:alignment("CENTER")
		:text(icon)
	pvt:newText("tooltip")
		:pos(-0.75, 0, 0)
		:scale(1 / 32)
		:background(true)

	return outline
end

local outlines = {
	hover = newOutline(vec(1, 1, 1, 0.4), ":skull_4:"),
	error = newOutline(vec(1, 0, 0, 0.4), "§4✖"),
}

---@type FOXSkull
local skull = require("./FOXSkull")
local get = skull.get

---@param block BlockState?
---@param entity Entity?
---@return boolean? visible
---@return number? offset
---@return number? distance
local function getHovering(block, entity)
	local pos =
		block and block:getPos() + 0.5 or
		entity and entity:getPos()

	if not pos then return end

	local scr = vectors.toCameraSpace(pos)
	return scr.z > 0, (scr.xy):length(), (client.getCameraPos() - pos):length()
end

local viewer = client.getViewer()

---@type ModelPart
local outline
function events.skull_render(_, block, item, entity, context)
	if outline then outline:visible(false) end
	outline = nil

	if context:find("FIRST_PERSON") or context == "GUI" or context == "OTHER" then return end

	local priv = get(block or item)[1]
	if priv.error then
		outline = outlines.error

		if priv.error and priv.error ~= true then
			local visible, offset, distance = getHovering(block, entity)
			local isHovering = visible and offset < 0.75 and distance < 8

			local tooltip = outline.text.pvt:getTask("tooltip") --[[@as TextTask]]

			tooltip:visible(isHovering)
			if isHovering then
				tooltip:text("§c" .. priv.error)
			end
		end
	elseif block and (get(viewer:getHeldItem()) or get(viewer:getHeldItem(true))) then
		local visible, offset, distance = getHovering(block, entity)
		local isHovering = visible and offset < 0.75 and distance < 16

		outline = isHovering and outlines.hover
	end

	if not outline then return end
	outline:visible(true)
end
