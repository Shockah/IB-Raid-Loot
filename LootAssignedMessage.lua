--[[
	LootAssignedMessage
	(master -> raiders)

	Properties:
	* loot: table -- Loot instance
	* roll: table -- Roll instance
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.LootAssignedMessage = {}
local Class = Addon.LootAssignedMessage

function Class:New(loot, roll)
	local obj = S:Clone(prototype)
	obj.loot = loot
	obj.roll = roll
	return obj
end

function prototype:Send()
	Addon:SendCompressedCommMessage("LootAssigned", {
		lootID = self.loot.lootID,
		player = self.roll and self.roll.player or nil,
	}, "RAID")
end

function Class:Handle(message, distribution, sender)
	local loot = Addon.lootHistory:Get(message.lootID)
	if not loot then
		return
	end

	local roll = nil
	local player = message.player
	if player then
		player = S:GetPlayerNameWithRealm(message.player)
		roll = loot:GetRollForPlayer(player)
	end

	if roll then
		roll.assigned = true
		table.insert(loot.assigned, {
			timer = nil,
			roll = roll,
		})
	else
		table.insert(loot.assigned, {})
	end
	
	if Addon.PendingFrame.frame then
		Addon.PendingFrame.frame:Update()
	end
end