---@diagnostic disable: undefined-field
---@meta FOXSkull

--#REGION ˚♡ Vars ♡˚

---@type FOXSkull
local skull = require("../FOXSkull")
local get, new = skull.get, skull.new


local vanillaSkull = models:newPart("vanillaSkull", "Skull"):visible(false)
local skullItem = vanillaSkull:newItem("Skull")
	:pos(0, 8, 0)
	:item("minecraft:player_head")

pcall(skullItem.item, skullItem, "minecraft:player_head" .. toJson { SkullOwner = avatar:getEntityName() })


local blank = textures:newTexture("", 1, 1)

local invisibleSkull = models:newPart("invisibleSkull", "Skull"):visible(false)
invisibleSkull:newSprite("Sprite"):setTexture(blank)


---@type ModelPart
local model
---@type number
local sharedDelta

--#ENDREGION
--#REGION ˚♡ Render ♡˚

function events.skull_render(delta, block, item, entity, context)
	-- Update vars

	---@type BlockState|ItemStack
	local this = block or item
	
	---@type FOXSkull.any
	local self = get(this) or new(this)
	local priv = self[1]

	local time = client.getSystemTime()
	if priv.timestamp ~= time and sharedDelta ~= delta then
		priv.contexts = {}
	end
	priv.timestamp = time
	sharedDelta = delta

	self.block = block
	self.item = item
	self.entity = entity
	---@diagnostic disable-next-line: assign-type-mismatch
	self.context = context

	priv.contexts[context] = { entity }


	-- Skull is rendering, run its render function

	if self.render and not priv.error then
		self:try(self.render, delta, self, this)
	end


	-- Update the skull's model

	if model then model:visible(false) end
	model = nil

	if priv.error then
		model = vanillaSkull
	elseif priv.visible then
		if priv.flatModel and (context == "GUI" or context == "OTHER") then
			model = priv.flatModel
		elseif priv.bakedModel and not priv.model then
			local mat = priv.itemMats[context]
			if mat then priv.bakedPivot:matrix(mat) end
			model = priv.bakedModel
		else
			model = priv.model
		end
	else
		model = invisibleSkull
	end

	if model then model:visible(true) end
end

--#ENDREGION
