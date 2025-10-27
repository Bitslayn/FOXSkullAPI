> [!IMPORTANT]
> This page is incomplete! Please keep this in mind when reading

When a skull has been initialized, it can be indexed via the item or block that created it, the block position if it is a placed skull, or its UUID. UUIDs are randomly generated when a skull is initialized.

> [!WARNING]
> You always want to nil check when indexing skulls as they could be removed at any time

Skulls can be indexed from the `skulls` table returned to you when you require the API:

```lua
-- Do not copy this snippet

local skulls = require("SkullAPI/module")
local skull = skulls[vec(0, 0, 0)]
```

## Indexing by BlockState/ItemStack

> [!NOTE]
> When you index by a BlockState, you will be given a `FOXSkull.block`
>
> For ItemStacks, you are given a `FOXSkull.item` instead

It is quite rare to come into a situation where you'd need to index a skull by its BlockState or ItemStack, but it is possible nonetheless. Cases where you'd actually need to do so are when you:

* Are using a patpat script such as AuriaPat, BunnyPat, SlymePat, or MatPat- I mean FOXPat
* Get a table of blocks from something like `world.getBlocks()`
* Get a block directly by using `world.getBlockState()`
* **Get the held item of a player who's holding one of your skulls**

```lua
-- Example snippet of getting a skull held by a player when pressing right click

local bind = keybinds:newKeybind(
	"Get Target's Skull", -- Name
	"key.mouse.right"  -- Key
)

function bind.press()
	local target = player:getTargetedEntity()
	if not target then return end -- Nil check, there may not even be a target entity
	
	local heldItem = target:getHeldItem()
	local skull = skulls[heldItem] -- Index the skull by ItemStack

	print(skull and skull:getName()) -- Print skull name, or nil if a skull isn't held
end
```

## Indexing by position

> [!NOTE]
> When you index with a position, you will be given a `FOXSkull.block`

Skulls can be indexed by a block position. This can be useful if you want to quickly check if a skull exists at a block relative to the current skull's position.