local skulls = require("Scripts.SkullAPI.FOXSkullAPI")

function skulls.skull_init(skull)
	if skull:hasContext("ITEM") then
		skull:model(models.Models.Player, "ITEM")
	else
		skull:model(models.Models.Player, "BLOCK")
	end
end

function skulls.skull_deinit(skull)
	print("Removed skull: ", skull)
end
