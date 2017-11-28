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
local selfMessageType = "Loot"
Addon[selfMessageType.."Message"] = {}
local Class = Addon[selfMessageType.."Message"]
Addon.Comm.handlers[selfMessageType] = Class

function Class:New(loot)
	local obj = S:Clone(prototype)
	obj.loot = loot
	return obj
end

function prototype:Send()
	if not Addon:IsMasterLooter() then
		return
	end

	if S:IsEmpty(self.loot) then
		return
	end

	Addon:SendCompressedCommMessage(selfMessageType, {
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
	if Addon:IsMasterLooter() then
		return
	end

	local loot = S:Map(message.loot, function(loot)
		local lootObj = Addon.Loot:New(loot.lootID, loot.link, loot.quantity, false)
		lootObj:SetInitialRolls(loot.eligiblePlayers)
		return lootObj
	end)
	
	for _, lootObj in pairs(loot) do
		lootObj:AddToHistory(Addon.lootHistory, message.timeout)
	end

	local lootToDisplay = {}
	S:InsertAllUnique(lootToDisplay, loot)
	S:InsertAllUnique(lootToDisplay, S:Filter(Addon.lootHistory.loot, function(lootObj)
		return lootObj:IsPendingLocalRoll()
	end))

	local pendingFrame = Addon.PendingFrame:Get()
	pendingFrame:SetLoot(lootToDisplay)
	pendingFrame:Update()
	pendingFrame:Show()
end