---@meta FOXSkull

---@class FOXSkull.any
local anyClass = require("../../core/FOXSkull").class

---Sets the model to render for this skull
---@generic self
---@param self self
---@param model ModelPart?
---@return self
function anyClass:setModel(model)
	local priv = self[1]

	if not model then
		if not priv.model then return self end
		priv.model:getParent():remove()
		return self
	end

	local pivot
	if priv.model then
		pivot = priv.model
			:getParent()
			:pos(-model:getPivot())

		priv.model:remove()
	else
		pivot = models
			:newPart("skullPivot")
			:parentType("Skull")
			:pos(-model:getPivot())
	end

	priv.model = model
		:copy("skullModel")
		:moveTo(pivot)
		:visible(false)

	return self
end

---Sets the model to render for this skull
---@generic self
---@param self self
---@param model ModelPart?
---@return self
function anyClass:model(model)
	return self --[[@as FOXSkull.any]]:setModel(model)
end

---Gets the model set to render for this skull
---@return ModelPart
---@nodiscard
function anyClass:getModel()
	return self[1].model
end
