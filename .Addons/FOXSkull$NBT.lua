--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's SkullAPI Addon
]]

-- Base64

local base64 = {}

---Checks if the given string is a base64 string
---@param str string
---@return boolean
function base64.validate(str)
	return type(str) == "string" and #str % 4 == 0 and str:match("^[A-Za-z0-9+/]+=*$") == str
end

---Converts the given string to base64
---@param value string
---@return string
function base64.encode(value)
	local buffer = data:createBuffer()
	buffer:writeByteArray(value)
	buffer:setPosition(0)
	local encoded = buffer:readBase64()
	buffer:close()
	return encoded
end

---Converts from base64 to a readable string
---@param value string
---@return string
function base64.decode(value)
	local buffer = data:createBuffer()
	buffer:writeBase64(value)
	buffer:setPosition(0)
	local decoded = buffer:readByteArray()
	buffer:close()
	return decoded
end

-- Parsers

---@param str string
---@return string
local function parse_name(str)
	local name = parseJson(str)
	return name.text or name
end

---@param tbl table
---@return string
local function parse_lore(tbl)
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

---@param textures table
---@param i integer
---@param j integer
---@param signature string
---@return string
local function parse_textures(textures, i, j, signature)
	local data = ""
	for k = math.max(i, 1), math.min(j, #textures) do
		local texture = textures[k]
		local sig = texture.signature or texture.Signature
		if not signature or sig and sig:find(signature) then
			data = texture and data .. base64.decode(texture.value or texture.Value) or data
		end
	end
	return data
end

return function(skulls, class)
	---@class FOXSkullAPI
	skulls = skulls
	---@class FOXSkullAPI.Skull
	class = class

	---Gets the name of this skull from its block or item data
	---@return string
	---@nodiscard
	function class:getName()
		if self.item then
			return self.item:getName()
		else
			local block = self.block
			local data = block:getEntityData()
			if not data then return "Player Head" end
			return data.custom_name and parse_name(data.custom_name) or "Player Head" -- Block for 1.21+
		end
	end

	---Gets the lore of this skull from its item data
	---@return string?
	---@nodiscard
	function class:getLore()
		if not self.item then return end

		local tag = self.item.tag
		local lines = tag.display and tag.display.Lore or tag.lore or tag["minecraft:lore"]
		if not lines then return end
		return parse_lore(lines)
	end

	---Gets this skull's parsed texture data
	---
	---If a single integer is given, returns the texture field for that index
	---
	---If two integers are given, treats them as a range, returning those texture fields concatenated
	---
	---Concatenates all texture fields if no integers are given
	---
	---If a signature is provided, all textures without a matching signature will be skipped over
	---@param i integer?
	---@param j integer?
	---@param signature string?
	---@return string
	---@nodiscard
	function class:getData(i, j, signature)
		i, j = i or 1, j or i or math.huge

		local block = self.block
		local item = self.item
		local nbt = block and block:getEntityData() or item and item.tag
		if not nbt then return "" end

		local textures = nbt.SkullOwner and nbt.SkullOwner.Properties and nbt.SkullOwner.Properties.textures or -- < 1.21.9
			nbt.profile and nbt.profile.properties                                                        -- 1.21.9+

		return textures and parse_textures(textures, i, j, signature) or ""
	end
end
