--[[
	LootMessage

	Properties:
	* loot: table -- list of Loot objects
]]

local selfAddonName = "Linnet"
local Self = _G[selfAddonName]
local SelfDB = _G[selfAddonName.."DB"]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}

function Self:NewLootMessage(loot)
	local obj = S:Clone(prototype)
	obj.loot = {}
	return obj
end

function Self:HandleLootMessage(message)
	local loot = S:Map(message.loot, function (loot)
		return Self:NewLoot(loot.lootID, loot.link, loot.quantity, false)
	end)
	
	for _, lootObj in loot do
		lootObj:AddToHistory(self.lootHistory, message.timeout)
	end
end

function prototype:Send()
	Self:SendCompressedCommMessage("Loot", {
		loot = S:Map(self.loot, function (loot)
			return {
				lootID = loot.lootID,
				link = loot.link,
				quantity = loot.quantity,
			}
		end),
		timeout = SelfDB.RollTimeout
	}, "RAID")
end