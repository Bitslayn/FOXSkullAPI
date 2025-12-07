-- --[[
-- ____  ___ __   __
-- | __|/ _ \\ \ / /
-- | _|| (_) |> w <
-- |_|  \___//_/ \_\
-- FOX's SkullAPI v1.0.0-dev

-- Github: https://github.com/Bitslayn/FOXSkullAPI
-- Docs: https://github.com/Bitslayn/FOXSkullAPI/wiki
-- ]]

--==============================================================================================================================
--#REGION ˚♡ FOXSkull ♡˚
--==============================================================================================================================

local viewer = client.getViewer()

------------------------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Events ♡˚
------------------------------------------------------------------------------------------------

---Creates a new event that can be called
---@return table
local function new_event()
	return setmetatable({}, {
		__call = function() end,
		__newindex = function(s, k, v)
			rawset(s, k, v)

			-- local f1=_ENV[1]
			-- local f2=_ENV[2]
			-- local f3=_ENV[3]
			-- return function(...)f1(...)f2(...)f3(...)end

			local l, c = {}, {}
			for i = 1, #s do
				l[i] = string.format("local f%d=_ENV[%d]", i, i)
				c[i] = string.format("f%d(...)", i)
			end

			---@type function
			local f = load(string.format(
				"%s\nreturn function(...)%send",
				table.concat(l, "\n"),
				table.concat(c, "")
			), "event_meta", s)()

			-- function(...) f1(...); f2(...); f3(...); end

			getmetatable(s).__call = function(_, ...)
				f(...)
			end
		end,
	})
end

---@class FOXSkullAPI.Events
local skull_events = {
	skull_init = new_event(),
	block_init = new_event(),
	item_init = new_event(),

	skull_deinit = new_event(),
	block_deinit = new_event(),
	item_deinit = new_event(),

	skull_render = new_event(),
	skull_error = new_event(),
}

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Accessor ♡˚
------------------------------------------------------------------------------------------------

local function deep_table(d)
	return setmetatable({}, {
		__index = function(t, k)
			local v = d > 2 and deep_table(d - 1) or {}
			t[k] = v
			return v
		end,
	})
end

local blocks = deep_table(3)
local items = deep_table(3)

local default_model = models.Models.Player.Root.Neck.Head
	:copy("Skull")
	:parentType("None")
	:offsetRot()
default_model:pos(-default_model:getPivot())

---Creates a new skull
---@param block BlockState
---@param item ItemStack
---@param entity LivingEntity
---@param context string
---@return table
local function new(block, item, entity, context)
	local v = {
		block = block,
		item = item,
		entity = entity,
		context = context,
		uuid = client.intUUIDToString(client.generateUUID())
	}

	if default_model then
		v.OTHER = default_model:copy("OTHER")
			:parentType("Skull")
			:visible(false)
			:moveTo(models)
	end

	return v
end

---Gets the skull block or item, creating one if none exist
---@param block BlockState
---@param item ItemStack
---@param entity LivingEntity
---@param context string
---@return table
local function get(block, item, entity, context)
	if block then
		-- Skull blocks
		-- 15 instructions/t

		local x, y, z = block:getPos():unpack()

		local t = blocks[x][y]
		if t[z] then return t[z] end

		local v = new(block, item, entity, context)
		t[z] = v
		return v
	else
		-- Skull items
		-- 20 instructions/t

		local a = (entity or viewer):getUUID()
		local b = item:toStackString()
		local c = item:getCount()

		local t = items[a][b]
		if t[c] then return t[c] end

		local v = new(block, item, entity, context)
		t[c] = v
		return v
	end
end

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ FOXSkull > Process ♡˚
------------------------------------------------------------------------------------------------

---@type ModelPart?
local render_model

function events.skull_render(delta, ...)
	local skull = get(...)
	local ctx = select(4, ...)
	skull.context = ctx

	if render_model then
		render_model:visible(false)
	end

	local model = skull[ctx] or skull.OTHER
	render_model = model and model:visible(true)

	skull_events.skull_render(skull, delta, ctx)
end

--#ENDREGION

--#ENDREGION
