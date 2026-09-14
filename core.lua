---@diagnostic disable: invisible

local skull = require("./class/skull")
local modes = require("./class/mode")

local blocks = {}
local items = {}

local mdp = skull.defaultModel

function events.skull_render(delta, block, item, entity, ctx)
	mdp:visible(false)

	if block then
		local key = block:getPos() .. skull.blockHash
		local self = blocks[key] or skull.newBlock(blocks, key, block)
		mdp = self.model:visible()
		self.render(delta, self, ctx)
	else
		local key = item.tag.SkullOwner.Properties.textures[1].Value .. item:getName()
		local self = items[key] or skull.newItem(items, key, item)
		mdp = self.model:visible()
		self.render(delta, self, ctx)
	end
end
