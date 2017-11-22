--[[
	LootMessage

	Properties:
	* loot: table -- list of Loot objects
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local DB = _G[selfAddonName.."DB"]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.LootMessage = {}
local Class = Addon.LootMessage

function Class:New(loot)
	local obj = S:Clone(prototype)
	obj.loot = {}
	return obj
end

function Class:Handle(message)
	local loot = S:Map(message.loot, function (loot)
		return Addon.Loot:New(loot.lootID, loot.link, loot.quantity, false)
	end)
	
	for _, lootObj in loot do
		lootObj:AddToHistory(self.lootHistory, message.timeout)
	end
end

function prototype:Send()
	Addon:SendCompressedCommMessage("Loot", {
		loot = S:Map(self.loot, function (loot)
			return {
				lootID = loot.lootID,
				link = loot.link,
				quantity = loot.quantity,
			}
		end),
		timeout = DB.RollTimeout
	}, "RAID")
end