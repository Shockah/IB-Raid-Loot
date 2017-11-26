--[[
	LootHistory

	Properties:
	* loot: table -- list of Loot objects
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.LootHistory = {}
local Class = Addon.LootHistory

function Class:New()
	local obj = S:Clone(prototype)
	obj.loot = {}
	return obj
end

function prototype:Get(lootID)
	return S:FilterFirst(self.loot, function(loot)
		return loot.lootID == lootID
	end)
end

function prototype:Contains(lootID)
	return S:FilterContains(self.loot, function(loot)
		return loot.lootID == lootID
	end)
end

function prototype:GetAllNew()
	return S:Filter(self.loot, function(loot)
		return loot.isNew
	end)
end

function prototype:GetNonAssignedLoot()
	return S:Filter(self.loot, function(loot)
		return not loot:IsFullyAssigned()
	end)
end

function prototype:FinishProcessingNewLoot()
	for _, loot in pairs(self.loot) do
		loot.isNew = false
	end
end