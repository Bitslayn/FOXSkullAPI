---@diagnostic disable: undefined-field
---@meta FOXSkull

--#REGION ˚♡ Vars ♡˚

---@type FOXSkull
local skull = require("../FOXSkull")
local all = skull.all

--#ENDREGION
--#REGION ˚♡ Tick ♡˚

function events.world_tick()
	for _, self in pairs(all) do
		local priv = self[1]
		if self.tick and not priv.error then
			for _, params in pairs(priv.contexts) do
				self.entity = params[1]
				self:try(self.tick, self)
			end
		end
	end
end

--#ENDREGION