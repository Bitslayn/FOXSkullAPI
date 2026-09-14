---@class FOXSkull
local api = {}

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