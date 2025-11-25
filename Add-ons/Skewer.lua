---Converts a ModelPart into a model path string
---@param model ModelPart
---@return string
local function toPath(model)
	local path = {}
	while model:getParent() do
		table.insert(path, 1, model:getName())
		model = model:getParent()
	end
	return table.concat(path, ".")
end

---Converts a ModelPart into a table of model path strings
---@param model ModelPart
---@return string[]
local function toPathTbl(model)
	local path = {}
	while model:getParent() do
		table.insert(path, 1, model:getName())
		model = model:getParent()
	end
	return path
end

---Converts a model path string into a ModelPart
---@param path string
---@param part ModelPart?
---@return ModelPart
local function parsePath(path)
	local part = models
	for s in path:gmatch("[^%.]*") do
		part = part[s] or (s == part:getName() or s == "") and part or nil
	end
	return part
end

---Maps and returns the relatives between the two given ModelParts
---
---The returned table will contain the two given parts
---@param mdlA ModelPart
---@param mdlB ModelPart
---@return ModelPart[]
local function mapRelatives(mdlA, mdlB)
	local pathsA, pathsB = toPathTbl(mdlA), toPathTbl(mdlB)

	---@type ModelPart[]
	local relatives = {}
	---@type ModelPart, ModelPart, ModelPart
	local a, b, c = mdlA, nil, mdlB

	-- Find middle relative

	for i = 1, math.max(#pathsA, #pathsB) do
		if pathsA[i] ~= pathsB[i] then
			b = parsePath(table.concat(pathsA, ".", 1, i - 1))
			pathsB = { table.unpack(pathsB, i) }
			break
		end
	end

	-- Map relatives from a to b

	local _a = a
	repeat
		table.insert(relatives, _a)
		_a = _a:getParent()
	until _a == b

	table.insert(relatives, b)

	-- Map relatives from b to c

	local _b = b
	for _, name in pairs(pathsB) do
		_b = _b[name]
		table.insert(relatives, _b)
	end

	return relatives
end

-- print(mapRelatives(models.Models.Player.Root.Neck.Head, models.Models.Player.Root.Body))


local matPos = matrices.translate4
local matRot = matrices.rotation4
local matScl = matrices.scale4

---Calculates and returns this ModelPart's matrix
---@param part ModelPart
local function getMatrix(part)
	local pvt = matPos(part:getTruePivot())
	local pos = matPos(part:getTruePos())
	local rot = matRot(part:getTrueRot())
	local scl = matScl(part:getTrueScale())

	return pvt * pos * rot * scl
end

local pvt, pos, rot, scl = vec(0, -8, 0), vec(0, 8, 0), vec(45, 45, 45), vec(2, 3, 1)

local ___worldA = models:newPart("__world", "World")
	:pivot(pvt)
	:pos(pos)
	:rot(rot)
	:scale(scl)

local ___worldB = models:newPart("__world", "World")

___worldB:matrix(getMatrix(___worldA))

___worldA:newBlock("a")
	:block("minecraft:red_stained_glass")

___worldB:newBlock("b")
	:block("minecraft:blue_stained_glass")
