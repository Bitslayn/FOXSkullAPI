local skulls = require("Scripts.SkullAPI.FOXSkullAPI")

local default = models.Models.Player.Root.Neck.Head
	:copy("Skull")
	:parentType("None")
	:offsetRot()
default:pos(-default:getPivot())

function skulls.skull_init(skull)
	skull:model(default)
end

function skulls.skull_deinit(skull)
	print("Removed skull: ", skull)
end
