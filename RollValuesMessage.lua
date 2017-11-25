--[[
	RollValuesMessage
	(master -> raiders)

	Properties:
	* loot: table -- Loot instance
	* roll: table -- Roll instance
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
Addon.RollValuesMessage = {}
local Class = Addon.RollValuesMessage

function Class:New(loot, roll)
	local obj = S:Clone(prototype)
	obj.loot = loot
	obj.roll = roll
	return obj
end

function prototype:Send()
	Addon:SendCompressedCommMessage("RollValues", {
		lootID = self.loot.lootID,
		player = self.roll.player,
		type = self.roll.type,
		values = self.roll.values,
	}, "RAID")
end

function Class:Handle(message, distribution, sender)
	local loot = Addon.lootHistory:Get(message.lootID)
	if not loot then
		return
	end

	local player = S:GetPlayerNameWithRealm(message.player)
	local roll = loot:GetRollForPlayer(player)
	if not roll then
		return
	end

	roll.type = message.type
	roll.values = message.values
	
	if Addon.PendingFrame.frame then
		Addon.PendingFrame.frame:Update()
	end
end