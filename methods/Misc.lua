---@diagnostic disable: undefined-field
---@meta FOXSkull

---@class FOXSkull.any
local anyClass = require("../FOXSkull").class

---Sets this skull's visibility
---@generic self
---@param self self
---@param state boolean?
---@return self
function anyClass:setVisible(state)
	self[1].visible = state == nil and true or state
	return self
end

---Sets this skull's visibility
---@generic self
---@param self self
---@param state boolean?
---@return self
function anyClass:visible(state)
	return self --[[@as FOXSkull.any]]:setVisible(state)
end

---Gets this skull's visibility
---@return boolean
---@nodiscard
function anyClass:getVisible()
	return self[1].visible
end

---Sets the function to run when this skull renders
---@overload fun(self: FOXSkull.block, func: FOXSkull.block.render): FOXSkull.block
---@overload fun(self: FOXSkull.item, func: FOXSkull.item.render): FOXSkull.item
---@overload fun(self: FOXSkull.any, func: FOXSkull.any.render): FOXSkull.any
function anyClass:setRender(func)
	self.render = func
	return self
end

---Sets the function to run when this skull ticks
---@overload fun(self: FOXSkull.block, func: FOXSkull.block.tick): FOXSkull.block
---@overload fun(self: FOXSkull.item, func: FOXSkull.item.tick): FOXSkull.item
---@overload fun(self: FOXSkull.any, func: FOXSkull.any.render): FOXSkull.any
function anyClass:setTick(func)
	self.tick = func
	return self
end

---Gets this skull's uuid
---@return string
---@nodiscard
function anyClass:getUUID()
	return self[1].uuid
end
