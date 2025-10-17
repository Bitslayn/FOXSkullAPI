--#REGION ˚♡ Vars ♡˚

---@type FOXSkull
local skull = require("../FOXSkull")
local all, remove = skull.all, skull.remove

--#ENDREGION
--#REGION ˚♡ Flush ♡˚

---@type FOXSkull.key.internalID
local key
function events.skull_render()
	key = next(all, key)
	local self = all[key]
	if not self then return end

	local block = self --[[@as FOXSkull.block]].block

	local timer = block and 50 or 2000
	if client.getSystemTime() - self[1].timestamp < timer then return end

	if block then
		local pos = block:getPos()
		if world.isChunkLoaded(pos) and world.getBlockState(pos) == block then return end
	end

	remove(key)
	key = nil
end

--#ENDREGION