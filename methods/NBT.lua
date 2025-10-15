---@diagnostic disable: undefined-field
---@meta FOXSkull

---@class FOXSkull.any
local anyClass = require("../core/FOXSkull").class
---@class FOXSkull.block: FOXSkull.any
local blockClass = anyClass
---@class FOXSkull.item: FOXSkull.any
local itemClass = anyClass

--#REGION ˚♡ Name ♡˚

local defaultName = avatar:getEntityName() .. "'s Head"

---@param json string
---@return string
local function parseName(json)
	local name = parseJson(json)
	return name.text or name
end

---Gets the name of this skull from its block or item data
---@generic self
---@param self self
---@return string
---@nodiscard
function anyClass:getName()
	if self --[[@as FOXSkull.item]].item then
		return self --[[@as FOXSkull.item]].item:getName()
	else
		local block = self --[[@as FOXSkull.block]].block
		local data = block:getEntityData()
		if not data then return defaultName end
		return data.custom_name and parseName(data.custom_name) or defaultName -- Block for 1.21+
	end
end

--#ENDREGION
--#REGION ˚♡ Lore ♡˚

local function parseLore(tbl)
	local lore = {}

	for _, line in ipairs(tbl) do
		local lineJson = parseJson(line)

		if type(lineJson) == "table" then
			local text = ""

			-- NBT <1.20.5

			for _, sectJson in ipairs(lineJson) do
				text = text .. (sectJson.text or sectJson)
			end

			-- Components 1.20.5+

			if lineJson.text then
				text = text .. lineJson.text
				for _, sectJson in ipairs(lineJson.extra) do
					text = text .. (sectJson.text or sectJson)
				end
			end

			lineJson = text
		end

		table.insert(lore, lineJson.text or lineJson)
	end

	return table.concat(lore, "\n")
end

---Gets the lore of this skull from its item data
---@return string?
---@nodiscard
function itemClass:getLore()
	local tag = self.item.tag
	local lines = tag.display and tag.display.Lore or tag.lore or tag["minecraft:lore"]
	if not lines then return end
	return parseLore(lines)
end

--#ENDREGION
--#REGION ˚♡ Data ♡˚

---@param str string
local function parseBase64(str)
	local buffer = data:createBuffer()
	buffer:writeBase64(str)
	buffer:setPosition(0)
	local decoded = buffer:readByteArray()
	buffer:close()
	return decoded
end

---@param textures table
---@return string
local function parseTextures(textures)
	local data = {}
	for i, texture in ipairs(textures) do
		data[i] = parseBase64(texture.value or texture.Value)
	end
	return table.concat(data, "")
end

---Gets this skull's parsed texture data
---@generic self
---@param self self
---@return string
---@nodiscard
function anyClass:getData()
	local block = self --[[@as FOXSkull.block]].block
	local item = self --[[@as FOXSkull.item]].item
	local nbt = block and block:getEntityData() or item and item.tag
	if not nbt then return "" end

	local textures = nbt.SkullOwner and nbt.SkullOwner.Properties and nbt.SkullOwner.Properties.textures or -- < 1.21.9
		nbt.profile and nbt.profile.properties                                                           -- 1.21.9+

	return textures and parseTextures(textures) or ""
end

--#ENDREGION
