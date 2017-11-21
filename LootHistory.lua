--[[
	LootHistory

	Properties:
	* loot: table -- list of Loot objects
]]

local selfAddonName = "Linnet"
local Self = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}

function Self:NewLootHistory()
	local obj = S:Clone(prototype)
	obj.loot = {}
	return obj
end

function prototype:Get(lootID)
	return S:FilterFirst(self.loot, function (loot)
		return loot.lootID == lootID
	end)
end

function prototype:Contains(lootID)
	return S:ContainsMatching(self.loot, function (loot)
		return loot.lootID == lootID
	end)
end

function prototype:GetAllNew()
	return S:Filter(self.loot, function (loot)
		return loot.isNew
	end)
end

function prototype:FinishProcessingNewLoot()
	for _, loot in pairs(self.loot) do
		loot.isNew = false
	end
end