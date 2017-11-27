--[[
	RollMessage
	(raider -> master)

	Properties:
	* loot: table -- Loot instance
	* type: string -- roll type
]]

local selfAddonName = "Linnet"
local Addon = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

local prototype = {}
local selfMessageType = "Roll"
Addon[selfMessageType.."Message"] = {}
local Class = Addon[selfMessageType.."Message"]
Addon.Comm.handlers[selfMessageType] = Class

function Class:New(loot, type)
	local obj = S:Clone(prototype)
	obj.loot = loot
	obj.type = type
	return obj
end

function prototype:Send()
	if Addon:IsMasterLooter() then
		return
	end

	local lootMethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
	if lootMethod == "master" and masterLooterPartyID ~= 0 and masterLooterRaidID then
		local target, targetRealm = UnitName("raid"..masterLooterRaidID)
		if targetRealm then
			target = target.."-"..targetRealm
		end

		Addon:SendCompressedCommMessage(selfMessageType, {
			lootID = self.loot.lootID,
			type = self.type,
		}, "WHISPER", target)
	end
end

function Class:Handle(message, distribution, sender)
	if not Addon:IsMasterLooter() then
		return
	end

	local loot = Addon.lootHistory:Get(message.lootID)
	if not loot then
		return
	end

	sender = S:GetPlayerNameWithRealm(sender)
	local roll = loot:GetRollForPlayer(sender)
	roll:SetType(message.type)
	roll:SendRoll(loot)

	loot:HandleDoneRollingActions()
	if Addon.PendingFrame.frame then
		Addon.PendingFrame.frame:Update()
	end
end