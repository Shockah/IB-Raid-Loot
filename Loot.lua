--[[
	Loot

	Properties:
	* lootID: string -- unique loot ID
	* link: string -- item link
	* quantity: int
	* isNew: bool -- whether this Loot object is still being processed for the first time
]]

local selfAddonName = "Linnet"
local Self = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}

function Self:NewLoot(lootID, link, quantity, isNew)
	local obj = S:Clone(prototype)
	obj.lootID = lootID
	obj.link = link
	obj.quantity = quantity or 1
	obj.isNew = (isNew == nil and true or isNew)
	return obj
end