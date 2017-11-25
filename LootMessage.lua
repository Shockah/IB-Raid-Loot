--[[
	LootMessage
	(master -> raiders)

	Properties:
	* loot: table -- list of Loot objects
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.LootMessage = {}
local Class = Addon.LootMessage

function Class:New(loot)
	local obj = S:Clone(prototype)
	obj.loot = loot
	return obj
end

function prototype:Send()
	if S:IsEmpty(self.loot) then
		return
	end

	Addon:SendCompressedCommMessage("Loot", {
		loot = S:Map(self.loot, function(loot)
			return {
				lootID = loot.lootID,
				link = loot.link,
				quantity = loot.quantity,
				eligiblePlayers = S:Map(loot.rolls, function(roll)
					return roll.player
				end),
			}
		end),
		timeout = self.loot[1].timeout,
		hideRollsUntilFinished = self.loot[1].hideRollsUntilFinished,
	}, "RAID")
end

function Class:Handle(message, distribution, sender)
	local loot = S:Map(message.loot, function(loot)
		local lootObj = Addon.Loot:New(loot.lootID, loot.link, loot.quantity, false)
		lootObj:SetInitialRolls(loot.eligiblePlayers)
		return lootObj
	end)
	
	for _, lootObj in pairs(loot) do
		lootObj:AddToHistory(Addon.lootHistory, message.timeout)
	end

	local pendingFrame = Addon.PendingFrame:Get()
	pendingFrame:SetLoot(Addon.lootHistory.loot)
	pendingFrame:Show()
end