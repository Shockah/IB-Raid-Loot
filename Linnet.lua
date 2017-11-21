local selfAddonName = "Linnet"

Linnet = LibStub("AceAddon-3.0"):NewAddon(selfAddonName, "AceEvent-3.0", "AceComm-3.0", "AceBucket-3.0", "AceTimer-3.0")
local Self = _G[selfAddonName]
local S = LibStub:GetLibrary("ShockahUtils")

--local LibWindow = LibStub("LibWindow-1.1")

Self.Settings = {
	Debug = {
		Settings = true,
		Messages = true,
		AlwaysMasterLooter = true,
	},
	AceCommPrefix = "Linnet",
	LootAssignTimeout = 2, -- seconds
	LootReadyBucketPeriod = 0.2, -- seconds
}

if not _G[selfAddonName.."DB"] then
	_G[selfAddonName.."DB"] = {
		RollTimeout = 120, -- seconds
		QualityThreshold = LE_ITEM_QUALITY_EPIC, -- minimum quality to consider
		AutoProceed = { -- automatically distribute loot when all the rolls are done
			Enabled = false,
			OnlyIfEveryoneResponded = true,
		},
	}
end
local SelfDB = _G[selfAddonName.."DB"]

if Self.Settings.Debug.Settings then
	SelfDB.RollTimeout = 30
	SelfDB.QualityThreshold = LE_ITEM_QUALITY_POOR
end

local isLootWindowOpen = false
local lootCache = nil

function Self:OnInitialize()
	self.lootHistory = self:NewLootHistory()

	self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnItemInfoReceived")
	self:RegisterBucketEvent("LOOT_READY", self.Settings.LootReadyBucketPeriod, "OnLootReady")
	self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")

	self:RegisterComm(self.Settings.AceCommPrefix)
end

function Self:OnDisable()
	self:UnregisterAllEvents()
end

function Self:OnItemInfoReceived(event, itemID)
	self:HandleItemInfoResponse(itemID)
end

function Self:IsMasterLooter()
	if Self.Settings.Debug.AlwaysMasterLooter then
		return true
	end

	if not IsInRaid() then
		return false
	end

	local lootMethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
	return lootMethod == "master" and partyMaster == 0
end

function Self:OnLootReady()
	isLootWindowOpen = true
	if not self:IsMasterLooter() then
		return
	end

	lootCache = self:CacheLootIDs()

	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		if GetLootSlotType(i) == LOOT_SLOT_ITEM then
			local texture, item, quantity, quality = GetLootSlotInfo(i)

			if quality >= SelfDB.QualityThreshold and quantity == 1 then
				local lootID = self:LootIDForLootFrameSlot(i)
				if lootID then
					-- looted item is valid for rolling

					local loot = self.lootHistory:Get(lootID)
					if not loot then
						loot = self:NewLoot(lootID, GetLootSlotLink(i), 0)
						loot:AddToHistory(self.lootHistory)
					end

					if loot.isNew then
						loot.quantity = loot.quantity + 1
						self:DebugPrint("New loot item: "..loot.link.." x"..loot.quantity)
					end
				end
			end
		end
	end

	local newLoot = self.lootHistory:GetAllNew()
	if not S:IsEmpty(newLoot) then
		self:NewLootMessage(newLoot):Send()
		for _, loot in pairs(newLoot) do
			loot.isNew = false
		end
	end
end

function Self:OnLootClosed()
	isLootWindowOpen = false
end

function Self:CacheLootIDs()
	local cache = {}
	if not isLootWindowOpen then
		return cache
	end

	local numLootItems = GetNumLootItems()
	for i = 1, numLootItems do
		table.insert(cache, self:LootIDForLootFrameSlot(i))
	end

	return cache
end

local function GetCorpseID(corpseGuid)
	local _, _, _, _, _, mobID, spawnID = strsplit("-", corpseGuid)
	return mobID..":"..spawnID
end

function Self:LootIDForLootFrameSlot(lootSlotIndex)
	local corpseGuid = GetLootSourceInfo(lootSlotIndex)
	if not corpseGuid then
		return nil
	end
	local link = GetLootSlotLink(lootSlotIndex)
	return GetCorpseID(corpseGuid)..":"..string.gsub(link, "%|h.*$", "")
end

function Self:DebugPrint(message)
	if self.Settings.Debug.Messages then
		S:Dump(selfAddonName, message)
	end
end