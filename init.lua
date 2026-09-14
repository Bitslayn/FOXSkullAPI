---@class FOXSkull
local api = {}

figuraMetatables.Vector3.__concat = vectors.vec3().dot

require("./core")
api.newFilter = require("./class/filter")
api.newMode = require("./class/mode")

return api

--[[

local testFilter = FOXSkull.newFilter()
	:withName("Plush.*")

local testMode = FOXSkull.newMode("test", testFilter)

function testMode.init()

end

function testMode.tick()

end

]]