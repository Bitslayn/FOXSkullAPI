---@meta FOXSkull

---@class FOXSkull.block: FOXSkull.any
local blockClass = require("../FOXSkull").class

local dirs = {
	east  = vec(1, 0, 0),
	west  = vec(-1, 0, 0),
	floor = vec(0, 1, 0),
	south = vec(0, 0, 1),
	north = vec(0, 0, -1),
}

--#REGION ˚♡ AttachedBlock ♡˚

---Gets the block this skull is placed on
---@param distance number?
---@param invert boolean?
---@return BlockState
---@nodiscard
function blockClass:getAttachedBlock(distance, invert)
	local block = self.block

	distance = distance or 1
	invert = invert and -1 or 1

	local facing = block.properties.facing
	local pos = block:getPos() - (dirs[facing] or dirs.floor) * invert * distance
	return world.getBlockState(pos)
end

--#ENDREGION
--#REGION ˚♡ Center ♡˚

---Gets the visual center position of this skull in the world
---@return Vector3
---@nodiscard
function blockClass:getCenterPos()
	local block = self.block

	local shape = block:getOutlineShape()[1]
	local center = math.lerp(shape[1], shape[2], 0.5) + block:getPos()
	if self[1].model then center = center + self[1].model:getPos() / 16 end
	return center
end

--#ENDREGION
--#REGION ˚♡ Rotation ♡˚

---Gets the direction this skull is facing
---@return Vector3
---@nodiscard
function blockClass:getDir()
	local block = self.block

	local rot = tonumber(block.properties.rotation)
	if rot then
		local yaw = math.rad(rot * -22.5 - 180)
		return vec(math.sin(yaw), 0, math.cos(yaw))
	else
		local facing = block.properties.facing
		return dirs[facing]
	end
end

--#ENDREGION
--#REGION ˚♡ Floor ♡˚

---Aligns the skull model to the floor below it
---@param distance number
---@return self
function blockClass:alignToFloor(distance)
	if not self[1].model then return self end

	distance = distance or 1.25

	local startPos = self.block:getOutlineShape()[1][1] + self.block:getPos()
	local endPos = startPos - vec(0, distance, 0)

	local _, hit = raycast:block(startPos, endPos, "OUTLINE", "NONE")
	if hit == endPos then return self end
	self[1].model:pos(0, (startPos - hit):length() * -16)

	return self
end

--#ENDREGION
--#REGION ˚♡ Redstone ♡˚

---@return integer
---@nodiscard
function blockClass:getRedstoneLevel()
	local pos = self.block:getPos()
	local level = world.getRedstonePower(pos)

	return level
end

--#ENDREGION
